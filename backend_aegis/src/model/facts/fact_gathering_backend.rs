use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::Duration;
use rocket::futures::future::join_all;
use tokio::sync::mpsc::Sender;
use tokio::sync::Mutex;

use crate::config::Config;
use crate::model::cache::Cache;
use crate::model::db::update_topology::update_device_analytics;
use crate::model::facts::ansible::ansible_backend;
use crate::model::facts::generics::{Metrics, Status, StatusT, recursive_merge};
use crate::model::facts::icmp::icmp_backend;


/// Message variants sent to listeners
pub type FactMessage = (Metrics, StatusT);

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
    pub fn init() {
        let _ = Self::instance();
        icmp_backend::init();
        ansible_backend::init();

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

    pub async fn update_database(influx_client : &influxdb2::Client, msg: &FactMessage) {
        log::info!("[INFO ][FACTS] Updating Influx with metrics.");
        update_device_analytics(influx_client, &msg.0).await;
    }

    pub async fn update_cache(msg: FactMessage) {
        log::info!("[INFO ][FACTS] Updating local facts cache.");
        Cache::instance().update_facts(msg.0).await;
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
    pub async fn spawn_gather_task(influx_client : influxdb2::Client) {
        rocket::tokio::spawn(async move { 
            println!("[INFO ][FACTS] Waiting for web bindings to finish to begin fact gathering loop...");
            tokio::time::sleep(Duration::from_secs(2)).await;
            println!("[INFO ][FACTS] Beginning FactGathering Loop!");
        loop {
            // Spawn tasks non-blocking for each data source
            log::info!("[INFO ][FACTS] Gathering facts...");
            let icmp_handle    = rocket::tokio::task::spawn(async { icmp_backend::gather_facts().await });
            let ansible_handle = rocket::tokio::task::spawn(async { ansible_backend::gather_facts().await });

            // other tasks...
            
            let handles = vec![icmp_handle, ansible_handle];

            // Gather results off the tasks results
            let results: Vec<Result<(Metrics, StatusT), tokio::task::JoinError>> = join_all(handles).await;
            log::info!("[INFO ][FACTS] Gathered facts!");

            let results = Self::join_results(results);
            let exposed_fields = Self::extract_exposed_fields(&results.0);

            // Broadcast to listeners
            FactGatheringBackend::instance().broadcast(&results).await;
            Self::update_database(&influx_client, &results).await;
            Self::update_cache(results).await; // should be the last one, as it takes ownership

            let timeout_s = Config::instance().get("backend/controller/fact-gathering/polling_time_s", "/").unwrap_or(6);
            log::info!("[INFO ][FACTS] Sleeping until timeout ({}s) zzZ...", timeout_s);
            tokio::time::sleep(Duration::from_secs(timeout_s)).await;
        }});
    }


    pub fn join_results(results: Vec<Result<(Metrics, StatusT), tokio::task::JoinError>>) -> (Metrics, StatusT) {

        // Remember:
        //                             Device ->        { metric_name -> Metric}
        // pub type MetricsT = HashMap<String  , HashMap<String        , MetricValue>>;
        // pub type StatusT: = HashMap<String  , Status>;
        //
        // Results = [ Ansible MetricsT, ICMP MetricsT ]
        let mut combined_metrics = Metrics::new();
        let mut combined_status = StatusT::new();
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
                    .or_insert_with(Status::default);

                entry.merge(&device.1);
            }
        }

        (combined_metrics, combined_status)
    }

    pub fn extract_exposed_fields(metrics : &Metrics) -> HashMap<String, HashSet<String>> {
        let mut exposed = HashMap::new();

        for device in metrics {
            exposed.insert(device.0.clone(), device.1.keys().map(|k| k.to_string()).collect());
        }

        exposed
    }
}
