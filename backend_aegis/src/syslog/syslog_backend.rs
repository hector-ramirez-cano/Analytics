use std::collections::{HashMap};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, OnceLock};
use sqlx::{Pool, Postgres};
use tokio::net::UdpSocket;
use tokio::sync::mpsc::Sender;
use tokio::sync::Mutex;

use crate::config::Config;
use crate::model::db;
use crate::syslog::syslog_types::SyslogMessage;


pub struct SyslogBackend {
    listeners: Arc<Mutex<HashMap<usize, Sender<SyslogMessage>>>>,
    next_id: Arc<AtomicUsize>,
}

impl SyslogBackend {
    fn new() -> Self {
        SyslogBackend {
            listeners: std::sync::Arc::new(tokio::sync::Mutex::new(std::collections::HashMap::new())),
            next_id: std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(1)),
        }
    }

    pub fn instance() -> Arc<SyslogBackend> {
        static INSTANCE: OnceLock<Arc<SyslogBackend>> = OnceLock::new();
        INSTANCE.get_or_init(|| Arc::new(SyslogBackend::new())).clone()
    }

    /// Initialize
    pub fn init() {
        let _ = Self::instance();

        log::info!("[INFO ][SYSLOG] Init Syslog Backend");
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
    pub async fn add_listener(&self, sender: Sender<SyslogMessage>) -> usize {
        log::info!("[INFO ][SYSLOG] Registered listener");
        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        let mut guard = self.listeners.lock().await;
        guard.insert(id, sender);
        id
    }

    /// Remove a listener by id; returns whether any entry was removed
    pub async fn remove_listener(&self, id: usize) -> bool {
        log::info!("[INFO ][SYSLOG] Gracefully removed listener");
        let mut guard = self.listeners.lock().await;
        guard.remove(&id).is_some()
    }

    /// Remove all listeners
    pub async fn clear_listeners(&self) {
        log::info!("[INFO ][SYSLOG] Cleared all listeners");
        let mut guard = self.listeners.lock().await;
        guard.clear();
    }

    /// Broadcast a message to all listeners; prune dead ones
    /// Best-effort: ignores per-send errors and removes disconnected senders
    pub async fn broadcast(msg: &SyslogMessage) {
        let instance = SyslogBackend::instance();
        // Snapshot keys to avoid holding lock while awaiting send
        let keys_and_senders: Vec<(usize, Sender<SyslogMessage>)> = {
            let guard = instance.listeners.lock().await;
            guard.iter().map(|(&k, v)| (k, v.clone())).collect()
        };

        // Attempt sends; collect ids that failed so we can prune them
        let mut failed_ids = Vec::new();
        for (id, tx) in keys_and_senders {
            // try_send avoids awaiting; if it fails because buffer is full, consider spawning a task to await.
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
            let mut guard = instance.listeners.lock().await;
            for id in failed_ids {
                log::info!("[INFO ][SYSLOG] Forcefully removed listener for failed receive");
                guard.remove(&id);
            }
        }
    }

    pub async fn update_database(postgres_pool: &Pool<Postgres>, msg: &SyslogMessage) {
        log::info!("[INFO ][SYSLOG] Updating Postgres with syslog message!");

        match db::operations::syslog_operations::update_database(postgres_pool, msg).await {
            Ok(_) => (),
            Err(_) => {
                log::error!("[ERROR][SYSLOG] Failed to insert message into database. Syslog Message will be dropped");
                ()
            }
        }
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
    pub async fn spawn_gather_task(postgres_pool : Pool<Postgres>) {
        let config = Config::instance();
        let port = match config.get("backend/controller/api/syslog/RFC5424-port", "/") {
            Ok(v) => v,
            Err(_) => {
                log::error!("[ERROR][SYSLOG] During init: Syslog port not found, defaulting to 1514...");
                1514
            }
        };

        let addr = match config.get("backend/controller/api/syslog/bind_address", "/") {
            Ok(v) => v,
            Err(_) => {
                log::error!("[ERROR][SYSLOG] During init: Syslog bind address not found, defaulting to 0.0.0.0...");
                "0.0.0.0".to_owned()
            }
        };
        let bind_addr = format!("{addr}:{port}");

        let mut buf = [0u8; 2048];
        let socket = match UdpSocket::bind(&bind_addr).await {
            Ok(socket) => {
                log::info!("[INFO ][SYSLOG] Spawning syslog listener task bound to={}", &bind_addr);
                socket
            },
            Err(e) => {
                let e = format!("[ERROR][SYSLOG] Failed to bind to {} for syslog messages, e='{}'", &bind_addr, e);
                log::error!("{}", e);
                panic!("{}", e);
            }
        };

        // Syslog RFC5424, if RFC3164 support is needed, another thread can be spawned that sets 
        // syslog_loose::parse_message to Variant::RFC3164 and run it along side it, on a different port
        tokio::task::spawn_blocking(async move || {
            loop{
                let (len, _) = match socket.recv_from(&mut buf).await {
                    Ok((len, addr)) => (len, addr),
                    Err(e) => {
                        log::error!("[ERROR][SYSLOG] Failed to receive syslog message on {}, e={}", &bind_addr, e);
                        continue
                    }
                };
                let message = String::from_utf8_lossy(&mut buf[..len]);
                let message = syslog_loose::parse_message(&message, syslog_loose::Variant::RFC5424);
                let message: SyslogMessage = message.into();

                Self::update_database(&postgres_pool, &message).await;
                Self::broadcast(&message).await;
            }
        });

    }

}