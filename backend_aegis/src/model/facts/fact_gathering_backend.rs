use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::Duration;
use rocket::futures::future::join_all;
use sqlx::Postgres;
use tokio::sync::mpsc::Sender;
use tokio::sync::Mutex;

use crate::config::Config;
use crate::model::cache::Cache;
use crate::model::data::device_state::DeviceStatus;
use crate::model::db;
use crate::model::facts::ansible::ansible_backend;
use crate::model::facts::baseline::baseline_backend;
use crate::model::facts::generics::recursive_merge;
use crate::model::facts::snmp::snmp_backend;
use crate::types::{DeviceHostname, ExposedFields, MetricSet, Metrics, Status};
use crate::model::facts::icmp::icmp_backend;


/// Message variants sent to listeners
pub type FactMessage = HashMap<DeviceHostname, DeviceFacts>;

#[derive(Clone, Debug)]
pub struct DeviceFacts {
    pub metrics: MetricSet,
    pub status: DeviceStatus,
    pub exposed_fields: ExposedFields,
}

/// Singleton that stores listeners only
#[derive(Clone)]
pub struct FactGatheringBackend {
    listeners: Arc<Mutex<HashMap<usize, Sender<FactMessage>>>>,
    next_id: Arc<AtomicUsize>,
}

impl FactGatheringBackend {
    // Internal constructor
    fn new() -> Self {
        FactGatheringBackend {
            listeners: std::sync::Arc::new(tokio::sync::Mutex::new(std::collections::HashMap::new())),
            next_id: std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(1)),
        }
    }

    /// Get the singleton instance
    pub fn instance() -> Arc<FactGatheringBackend> {
        static INSTANCE: OnceLock<Arc<FactGatheringBackend>> = OnceLock::new();
        INSTANCE.get_or_init(|| Arc::new(FactGatheringBackend::new())).clone()
    }

    /// Initialize
    pub fn init(influx_client : &influxdb2::Client) {
        let _ = Self::instance();
        icmp_backend::init();
        snmp_backend::init();
        ansible_backend::init();
        baseline_backend::init(influx_client);

        println!("[INFO ][FACTS] Init Fact Gathering Backend");
    }



    //  __        __              __                                                     ______   _______   ______ 
    // /  |      /  |            /  |                                                   /      \ /       \ /      |
    // $$ |      $$/   _______  _$$ |_     ______   _______    ______    ______        /$$$$$$  |$$$$$$$  |$$$$$$/ 
    // $$ |      /  | /       |/ $$   |   /      \ /       \  /      \  /      \       $$ |__$$ |$$ |__$$ |  $$ |  
    // $$ |      $$ |/$$$$$$$/ $$$$$$/   /$$$$$$  |$$$$$$$  |/$$$$$$  |/$$$$$$  |      $$    $$ |$$    $$/   $$ |  
    // $$ |      $$ |$$      \   $$ | __ $$    $$ |$$ |  $$ |$$    $$ |$$ |  $$/       $$$$$$$$ |$$$$$$$/    $$ |  
    // $$ |_____ $$ | $$$$$$  |  $$ |/  |$$$$$$$$/ $$ |  $$ |$$$$$$$$/ $$ |            $$ |  $$ |$$ |       _$$ |_ 
    // $$       |$$ |/     $$/   $$  $$/ $$       |$$ |  $$ |$$       |$$ |            $$ |  $$ |$$ |      / $$   |
    // $$$$$$$$/ $$/ $$$$$$$/     $$$$/   $$$$$$$/ $$/   $$/  $$$$$$$/ $$/             $$/   $$/ $$/       $$$$$$/ 

    /// Add a listener channel sender; returns a listener id
    pub async fn add_listener(&self, sender: Sender<FactMessage>) -> usize {
        log::info!("[INFO ][FACTS] Registered listener");
        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        let mut guard = self.listeners.lock().await;
        guard.insert(id, sender);
        id
    }

    /// Remove a listener by id; returns whether any entry was removed
    pub async fn remove_listener(&self, id: usize) -> bool {
        log::info!("[INFO ][FACTS] Gracefully removed listener");
        let mut guard = self.listeners.lock().await;
        guard.remove(&id).is_some()
    }

    /// Remove all listeners
    pub async fn clear_listeners(&self) {
        log::info!("[INFO ][FACTS] Cleared all listeners");
        let mut guard = self.listeners.lock().await;
        guard.clear();
    }

    /// Broadcast a message to all listeners; prune dead ones
    /// Best-effort: ignores per-send errors and removes disconnected senders
    pub async fn broadcast(&self, msg: &FactMessage) {
        #[cfg(debug_assertions)] { log::info!("[DEBUG][FACTS] Broadcasting messages. Listener count = {}", self.listener_count().await); }
        // Snapshot keys to avoid holding lock while awaiting send
        let keys_and_senders: Vec<(usize, Sender<FactMessage>)> = {
            let guard = self.listeners.lock().await;
            guard.iter().map(|(&k, v)| (k, v.clone())).collect()
        };

        // Attempt sends; collect ids that failed so we can prune them
        let mut failed_ids = Vec::new();
        for (id, tx) in keys_and_senders {
            
            // Here we try a non-blocking send first, then fallback to try_send semantics.
            match tx.try_send(msg.clone()) {
                Ok(_) => {}
                Err(e) => {
                    use tokio::sync::mpsc::error::TrySendError;
                    match e {
                        TrySendError::Closed(_closed_msg) => {
                            failed_ids.push(id);
                        }
                        TrySendError::Full(_full_msg) => {
                            // channel is full; try a short, awaited send to avoid dropping the message
                            // If that also fails because closed, mark for removal.
                            match tx.try_reserve() {
                                Ok(permit) => {
                                    permit.send(msg.clone());
                                }
                                Err(_) => {
                                    // treat inability to reserve as potential disconnect; don't panic
                                }
                            }
                        }
                    }
                }
            }
        }

        // prune failed senders
        if !failed_ids.is_empty() {
            let mut guard = self.listeners.lock().await;
            for id in failed_ids {
                log::info!("[INFO ][FACTS] Forcefully removed listener for failed receive");
                guard.remove(&id);
            }
        }
    }

    pub async fn update_database(pool: &sqlx::Pool<Postgres>, influx_client : &influxdb2::Client, msg: &FactMessage) {
        log::info!("[INFO ][FACTS] Updating Influx with metrics.");
        db::update_topology::update_device_analytics(influx_client, &msg).await;
        db::update_topology::update_device_metadata(pool, msg).await;
    }

    pub async fn update_cache(msg: FactMessage) {
        log::info!("[INFO ][FACTS] Updating local facts cache.");
        let cache = Cache::instance();
        
        for (hostname, facts) in &msg {
            let id = match cache.get_device_id(&hostname).await {
                Some(id) => id,
                None => {
                    log::error!("[ERROR][FACTS][CACHE] While updating device cache/status and exposed fields: Device wasn't found in cache. This should be unreachable!");
                    continue
                }
            };
            cache.set_device_status(id, &facts.status, &facts.exposed_fields).await;
        }

        cache.update_facts(msg).await;
    }

    /// Return the number of registered listeners (utility)
    pub async fn listener_count(&self) -> usize {
        let guard = self.listeners.lock().await;
        guard.len()
    }



    //   ______               __      __                            __                     
    //  /      \             /  |    /  |                          /  |                    
    // /$$$$$$  |  ______   _$$ |_   $$ |____    ______    ______  $$/  _______    ______  
    // $$ | _$$/  /      \ / $$   |  $$      \  /      \  /      \ /  |/       \  /      \ 
    // $$ |/    | $$$$$$  |$$$$$$/   $$$$$$$  |/$$$$$$  |/$$$$$$  |$$ |$$$$$$$  |/$$$$$$  |
    // $$ |$$$$ | /    $$ |  $$ | __ $$ |  $$ |$$    $$ |$$ |  $$/ $$ |$$ |  $$ |$$ |  $$ |
    // $$ \__$$ |/$$$$$$$ |  $$ |/  |$$ |  $$ |$$$$$$$$/ $$ |      $$ |$$ |  $$ |$$ \__$$ |
    // $$    $$/ $$    $$ |  $$  $$/ $$ |  $$ |$$       |$$ |      $$ |$$ |  $$ |$$    $$ |
    //  $$$$$$/   $$$$$$$/    $$$$/  $$/   $$/  $$$$$$$/ $$/       $$/ $$/   $$/  $$$$$$$ |
    //                                                                           /  \__$$ |
    //                                                                           $$    $$/ 
    //                                                                            $$$$$$/  
    pub async fn spawn_gather_task(pool: sqlx::Pool<Postgres>, influx_client : influxdb2::Client) {
        rocket::tokio::spawn(async move { 
            println!("[INFO ][FACTS] Waiting for web bindings to finish to begin fact gathering loop...");
            tokio::time::sleep(Duration::from_secs(2)).await;
            println!("[INFO ][FACTS] Beginning FactGathering Loop!");
        loop {
            // Spawn tasks non-blocking for each data source
            log::info!("[INFO ][FACTS] Gathering facts...");
            let icmp_handle    = rocket::tokio::task::spawn(async { icmp_backend::gather_facts().await });
            let ansible_handle = rocket::tokio::task::spawn(async { ansible_backend::gather_facts().await });
            let snmp_handle    = rocket::tokio::task::spawn(async { snmp_backend::gather_facts().await });
            let baseline_handle = rocket::tokio::task::spawn(async { baseline_backend::gather_facts().await });

            // other tasks...
            
            let handles = vec![icmp_handle, ansible_handle, baseline_handle, snmp_handle];

            // Gather results off the tasks results
            let results: Vec<Result<(Metrics, Status), tokio::task::JoinError>> = join_all(handles).await;
            log::info!("[INFO ][FACTS] Gathered facts!");

            let results = Self::join_results(results);

            // Broadcast to listeners
            FactGatheringBackend::instance().broadcast(&results).await;
            Self::update_database(&pool, &influx_client, &results).await;
            Self::update_cache(results).await; // should be the last one, as it takes ownership

            let timeout_s = Config::instance().get("backend/controller/fact-gathering/polling_time_s", "/").unwrap_or(6);
            log::info!("[INFO ][FACTS] Sleeping until timeout ({}s) zzZ...", timeout_s);
            tokio::time::sleep(Duration::from_secs(timeout_s)).await;
        }});
    }


    pub fn join_results(results: Vec<Result<(Metrics, Status), tokio::task::JoinError>>) -> FactMessage {

        let mut combined_metrics = Metrics::new();
        let mut combined_status = Status::new();
        for source_results in results {
            let (metrics, status) = match source_results {
                Err(_) => continue,
                Ok(r) => r
            };

            // Recursively merge metrics
            for device in metrics {
                let entry = combined_metrics
                    .entry(device.0)
                    .or_insert_with(HashMap::new);

                recursive_merge(entry, &device.1);
            }

            // Recursively merge status
            for device in status {
                let entry = combined_status
                    .entry(device.0)
                    .or_insert_with(DeviceStatus::default);

                entry.merge(device.1);
            }
        }

        let mut result = FactMessage::with_capacity(combined_metrics.len());
        for (hostname, metrics) in combined_metrics {
            let exposed_fields = Self::extract_exposed_fields(&metrics);
            let status = match combined_status.remove(&hostname) {
                Some(s) => s,
                None => {
                    log::error!("[ERROR][FACTS] While merging, device {} did not contain status. This coud should be unreachable!", &hostname);
                    continue;
                }
            };

            result.insert(hostname, DeviceFacts { 
                metrics,
                status,
                exposed_fields
            });
        }

        result

    }

    pub fn extract_exposed_fields(metrics : &MetricSet) -> ExposedFields {
        metrics.iter().map(|(name, _)| name.clone().to_string()).collect()
    }
}
