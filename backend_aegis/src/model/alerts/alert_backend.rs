use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::{RwLock, RwLockWriteGuard};
use tokio::sync::mpsc::{Receiver, Sender};
use tokio::sync::Mutex;
use tokio::sync::mpsc;

use crate::config::Config;
use crate::model::alerts::{AlertDataSource, AlertEvent, AlertRule};
use crate::model::cache::Cache;
use crate::model::data::device::Device;
use crate::model::facts::fact_gathering_backend::{FactGatheringBackend, FactMessage};
use crate::model::facts::generics::MetricValue;
use crate::syslog::syslog_backend::SyslogBackend;
use crate::syslog::syslog_types::SyslogMessage;



/// Singleton that stores listeners only
pub struct AlertBackend {
    listeners: Arc<Mutex<HashMap<usize, Sender<AlertEvent>>>>,
    next_id: Arc<AtomicUsize>,
    pool: sqlx::PgPool,
    facts_rules: RwLock<Vec<AlertRule>>,
    syslog_rules: RwLock<Vec<AlertRule>>,
    last_update: RwLock<u64>, // epoch seconds

    facts_cache: RwLock<FactMessage>,
}

static INSTANCE: OnceLock<Arc<AlertBackend>> = OnceLock::new();

impl AlertBackend {
    // Internal constructor
    fn new(pool: &sqlx::PgPool) -> Self {
        AlertBackend {
            listeners: std::sync::Arc::new(tokio::sync::Mutex::new(std::collections::HashMap::new())),
            next_id: std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(1)),
            pool: pool.clone(),

            facts_rules: RwLock::new(Vec::new()),
            syslog_rules: RwLock::new(Vec::new()),

            last_update: RwLock::new(0),

            facts_cache : RwLock::new((HashMap::new(), HashMap::new())),

        }
    }

    /// Get the singleton instance
    pub fn instance() -> Arc<AlertBackend> {
        INSTANCE.get().expect("AlertBackend not initialized").clone()
    }

    /// Initialize
    pub async fn init(pool: &sqlx::PgPool) {

        // Add listeners to react to events that require rule eval

        let (facts_channel_tx, facts_channel_rx) = mpsc::channel::<FactMessage>(64);
        let (syslog_channel_tx, syslog_channel_rx) = mpsc::channel::<SyslogMessage>(64);
        let (internal_event_tx, internal_event_rx) = mpsc::channel::<AlertEvent>(32);

        // Try to set instance Arc with provided value
        let backend = Arc::new(AlertBackend::new(pool));
        let innit_bruv = INSTANCE.set(backend);

        if let Err(_) = innit_bruv {
            println!("[WARN][ALERTS] Alerts backend was init more than once!. Ignoring second init...");
            return;
        }

        AlertBackend::instance().update_ruleset(true).await;

        FactGatheringBackend::instance().add_listener(facts_channel_tx).await;
        Self::spawn_eval_facts_task(facts_channel_rx, internal_event_tx.clone());

        SyslogBackend::instance().add_listener(syslog_channel_tx).await;
        Self::spawn_eval_syslog_task(syslog_channel_rx, internal_event_tx.clone());

        Self::spawn_event_handler(internal_event_tx, internal_event_rx);


        log::info!("[INFO ][ALERTS] Init Alert Backend");
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
    pub async fn add_listener(&self, sender: Sender<AlertEvent>) -> usize {
        log::info!("[INFO ][ALERTS] Registered listener");
        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        let mut guard = self.listeners.lock().await;
        guard.insert(id, sender);
        id
    }

    /// Remove a listener by id; returns whether any entry was removed
    pub async fn remove_listener(&self, id: usize) -> bool {
        log::info!("[INFO ][ALERTS] Gracefully removed listener");
        let mut guard = self.listeners.lock().await;
        guard.remove(&id).is_some()
    }

    /// Remove all listeners
    pub async fn clear_listeners(&self) {
        log::info!("[INFO ][ALERTS] Cleared all listeners");
        let mut guard = self.listeners.lock().await;
        guard.clear();
    }

    /// Broadcast a message to all listeners; prune dead ones
    /// Best-effort: ignores per-send errors and removes disconnected senders
    pub async fn broadcast(&self, msg: &AlertEvent) {
        // Snapshot keys to avoid holding lock while awaiting send
        let keys_and_senders: Vec<(usize, Sender<AlertEvent>)> = {
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
                log::info!("[INFO ][ALERTS] Forcefully removed listener for failed receive");
                guard.remove(&id);
            }
        }
    }

    /// Return the number of registered listeners (utility)
    pub async fn listener_count(&self) -> usize {
        let guard = self.listeners.lock().await;
        guard.len()
    }

    //  ________                                __
    // /        |                              /  |
    // $$$$$$$$/__     __  ______   _______   _$$ |_    _______
    // $$ |__  /  \   /  |/      \ /       \ / $$   |  /       |
    // $$    | $$  \ /$$//$$$$$$  |$$$$$$$  |$$$$$$/  /$$$$$$$/
    // $$$$$/   $$  /$$/ $$    $$ |$$ |  $$ |  $$ | __$$      \
    // $$ |_____ $$ $$/  $$$$$$$$/ $$ |  $$ |  $$ |/  |$$$$$$  |
    // $$       | $$$/   $$       |$$ |  $$ |  $$  $$//     $$/
    // $$$$$$$$/   $/     $$$$$$$/ $$/   $$/    $$$$/ $$$$$$$/
    //
        /// Spawns the task that will handle the evaluation of FactMessages against the rules
    pub fn spawn_eval_facts_task(mut receiver: Receiver<FactMessage>, event_tx : Sender<AlertEvent>,) {
        let _ = rocket::tokio::task::spawn(async move { 
            let instance = Self::instance();
            loop {
            let new_facts = if let Some(msg) = receiver.recv().await { msg } else { continue; };

            log::info!("[DEBUG][ALERTS] Alerts backend received facts...");
            log::debug!("[DEBUG][ALERTS] Alerts backend received facts...");

            let facts_rules = instance.facts_rules.read().await;
            let old_facts = instance.facts_cache.read().await;

            AlertBackend::eval_rules(&facts_rules, &old_facts, &new_facts, &event_tx).await;

            let mut old_facts = instance.facts_cache.write().await;
            *old_facts = new_facts;
        }});

        log::info!("[INFO ][ALERTS] Spawned Eval Facts Task");
    }

    /// Spawns the task that will handle the evaluation of SyslogMessages against the rules
    pub fn spawn_eval_syslog_task(mut receiver: Receiver<SyslogMessage>, event_tx: Sender<AlertEvent>) {
        let _ = rocket::tokio::task::spawn(async move {
        let instance = Self::instance();
        loop {
            let message = if let Some(msg) = receiver.recv().await { msg } else { continue; };

            let syslog_rules = instance.syslog_rules.read().await;

            // To emulate Metrics behavior, dynamically create a "MetricSet" with the given device, into a Metrics
            let old_facts = (HashMap::new(), HashMap::new());
            let mut new_facts = (HashMap::new(), HashMap::new());
            let mut syslog_fact = HashMap::new();
            syslog_fact.insert("syslog_message".to_string(), MetricValue::String(message.msg));
            new_facts.0.insert(message.hostname.unwrap_or("Unknown device!".to_string()), syslog_fact);

            AlertBackend::eval_rules(&syslog_rules, &old_facts, &new_facts, &event_tx).await;
        }});

        log::info!("[INFO ][ALERTS] Spawned Eval Syslog Task");
    }

    /// Spawns the task that will handle the events when they are received
    /// db writes are guaranteed. If the write fails, the event is requeued
    /// If it can't requeue, the event is dropped
    /// ws writes are best effort. If it fails, it just keeps going.
    pub fn spawn_event_handler(event_tx: Sender<AlertEvent>, mut event_rx: Receiver<AlertEvent>) {
        let _ = rocket::tokio::task::spawn(async move { 
            let instance = Self::instance();
        loop {
            let mut event = match event_rx.recv().await {
                Some(e) => e, None => continue
            };

            log::info!("[DEBUG][ALERTS] Received alert event!");

            // Write into db
            let id = crate::model::db::operations::alert_operations::insert_alert(&event, &instance.pool).await;
            match id {
                Ok(id) => { event.alert_id = id; event.db_notified = true; },
                Err(e) => {
                    log::error!("[ERROR][ALERTS] Failed to write alert to database with e = '{e}'. Requeueing...");
                    if let Err(e) = event_tx.send(event).await {
                        log::error!("[ERROR][ALERTS] Failed to requeue failed write alert event with e = '{e}'. Event will be skipped!")
                    };
                    continue;
                },
            }

            // Broadcast into listeners:
            instance.broadcast(&event).await;
        }});

        log::info!("[INFO ][ALERTS] Spawned handle events Task");
    }


    //  _______             __
    // /       \           /  |
    // $$$$$$$  | __    __ $$ |  ______    _______
    // $$ |__$$ |/  |  /  |$$ | /      \  /       |
    // $$    $$< $$ |  $$ |$$ |/$$$$$$  |/$$$$$$$/
    // $$$$$$$  |$$ |  $$ |$$ |$$    $$ |$$      \
    // $$ |  $$ |$$ \__$$ |$$ |$$$$$$$$/  $$$$$$  |
    // $$ |  $$ |$$    $$/ $$ |$$       |/     $$/
    // $$/   $$/  $$$$$$/  $$/  $$$$$$$/ $$$$$$$/

    async fn eval_rules(rules: &Vec<AlertRule>, old_facts: &FactMessage, new_facts : &FactMessage, event_tx: &Sender<AlertEvent>) {
        Self::instance().update_ruleset(false).await;

        for rule in rules.iter() {
                let item = match Cache::instance().get_evaluable_item(rule.target_item).await { Some(i) => i, None=> continue };

                let triggered = item.eval(rule, &old_facts, &new_facts).await;

                // if item trigered, raise an alert for each alerting item
                if let Some(t) = triggered {
                    for (item, which) in t {
                        match item {
                            crate::model::alerts::EvaluableItem::Group(_) => {
                                log::warn!("[WARN ][ALERTS] Alert triggered for group. This behavor is unexpected, as only devices can raise. Skipping...");
                                continue;
                            },
                            crate::model::alerts::EvaluableItem::Device(device) => {
                                let which = which.iter().map(|(lhs, op, rhs)| format!("[{} {} {}]", lhs, op, rhs)).collect::<Vec<_>>().join(", ");


                                AlertBackend::raise_alert(rule, &device, which, &event_tx).await;
                            },
                        }
                    }
                }
            }

    }

    /// Updates the local definition of the rules, only if an update is due, or if the update is forced
    async fn update_ruleset(&self, forced: bool) {
        let instance = Self::instance();

        // try to acquire a lock for the last_update lock  guard
        let last_update_lock = instance.try_claim_update(forced).await;

        // as long as this mfer lives, no one can access the rules
        let _last_update_lock = match last_update_lock {
            Some(l) => l, None => return
        };

        let rules = sqlx::query!("SELECT * FROM Analytics.alert_rules;").fetch_all(&self.pool).await;
        let rules = match rules { Ok(r) => r, Err(e) => {
            log::error!("[ERROR][ALERTS][LOADS] Failed to load rules from database with error = '{e}'");
            println!("[ERROR][ALERTS][LOADS] Failed to load rules from database with error = '{e}'");
            return;
        }};

        let mut facts_rules : Vec<AlertRule> = Vec::new();
        let mut syslog_rules : Vec<AlertRule> = Vec::new();

        for record in rules {
            let rule = match AlertRule::from_json(record.rule_id, record.rule_name.clone(), record.requires_ack, record.rule_definition) {
                Some(r) => r,
                None => {
                    log::warn!("[WARN ][ALERTS][LOADS] Failed to load rule {}-'{}' from database- Definition is invalid. Ignoring...", record.rule_id, record.rule_name);
                    println!("[WARN ][ALERTS][LOADS] Failed to load rule {}-'{}' from database- Definition is invalid. Ignoring...", record.rule_id, record.rule_name);
                    continue;
                }
            };

            match rule.data_source {
                AlertDataSource::Facts => facts_rules.push(rule),
                AlertDataSource::Syslog => syslog_rules.push(rule),
            }
        }

        log::info!("[INFO ][ALERTS][LOADS] Loaded {} fact rules, and {} syslog rules", facts_rules.len(), syslog_rules.len());
        println!("[INFO ][ALERTS][LOADS] Loaded {} fact rules, and {} syslog rules", facts_rules.len(), syslog_rules.len());

        Self::replace_rules(facts_rules, syslog_rules).await;
    }

    /// Loads multiple rules into the rule set
    async fn replace_rules(mut facts_rules: Vec<AlertRule>, mut syslog_rules: Vec<AlertRule>) {
        let instance = Self::instance();
        let mut w = instance.facts_rules.write().await;
        w.clear();
        w.append(&mut facts_rules);

        let mut w = instance.syslog_rules.write().await;
        w.clear();
        w.append(&mut syslog_rules);
    }

    /// Calls to raise an alert. The alert is placed into the [sender] queue, to be written to the database
    /// db writes are guaranteed. If the write fails, the event is requeued
    /// ws writes are best effort. If it fails, it just keeps going.
    async fn raise_alert(rule: &AlertRule, device: &Device, value: String, sender: &Sender<AlertEvent> ) {
        let event = AlertEvent {
            alert_id: -1,
            alert_time: None,
            ack_time: None,
            requires_ack: rule.requires_ack,
            severity: rule.severity,
            message: format!("'{}' Triggered for device='{}'", rule.name, device.device_name),
            target_id: device.device_id,
            ws_notified: false,
            db_notified: false,
            acked: false,
            rule_id: rule.rule_id,
            value,
        };

        match sender.send(event).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][ALERTS] Failed to send raised alert into alert handler! e='{e}'");
            }
        }
    }

    /// Last update (epoch seconds)
    pub async fn last_update(&self) -> u64 {
        let guard = self.last_update.read().await;
        *guard
    }

    async fn update_last(&self) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let mut w: RwLockWriteGuard<'_, u64> = self.last_update.write().await;
        *w = now;
    }

    /// Try to claim the update. If this returns Some(write_guard) the caller won the right
    /// to update and holds the write lock on `last_update`. Caller should perform the
    /// refresh while holding the guard and then drop it when done.
    ///
    /// Returns None if an update is not needed (someone else updated recently).
    pub async fn try_claim_update(&self, forced: bool) -> Option<RwLockWriteGuard<'_, u64>> {
        let interval_secs = Config::instance().get_value_opt ("backend/model/cache/rule_set_cache_invalidation_s", "/").unwrap_or_default().as_u64().unwrap_or(3600);

        // fast read-only check
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        // if the update isn't due, and the caller didn't request a forced update
        let last = *self.last_update.read().await;
        if now.saturating_sub(last) < interval_secs && !forced {
            return None;
        }


        // Acquire write lock (recover from poison if necessary)
        let mut last_w = self.last_update.write().await;


        // Re-check under the write lock to avoid races
        if now.saturating_sub(*last_w) < interval_secs {
            // somebody else updated while we were waiting for the write lock
            return None;
        }

        // claim: set last_update to now and return the guard so caller holds the lock
        *last_w = now;

        // return the guard so the caller keeps exclusive access while they perform updates
        Some(last_w)
    }

}