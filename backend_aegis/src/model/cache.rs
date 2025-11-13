use std::collections::{HashMap, HashSet};
use std::time::{SystemTime, UNIX_EPOCH};
use std::sync::{Arc, OnceLock};
use tokio::sync::{RwLock, RwLockWriteGuard};


use serde::Serialize;

use crate::config::Config;
use crate::alerts::EvaluableItem;
use crate::model::data::data_source::DataSource;
use crate::model::data::device::Device;
use crate::model::data::link::Link;
use crate::model::data::group::Group;
use crate::model::db::update_topology::update_topology_cache;
use crate::model::facts::generics::{MetricValue, Metrics};

async fn serialize_map<T: Serialize>(lock: &RwLock<HashMap<i64, T>>) -> Result<String, serde_json::Error> {
    serde_json::to_string(&*lock.read().await)
}

pub struct Cache {
    devices: RwLock<HashMap<i64, Device>>,
    links: RwLock<HashMap<i64, Link>>,
    groups: RwLock<HashMap<i64, Group>>,
    facts: RwLock<Metrics>,
    last_update: RwLock<u64>, // epoch seconds
}

impl Cache {
    /// Internal constructor, private
    fn new() -> Self {
        Self {
            devices: RwLock::new(HashMap::new()),
            links: RwLock::new(HashMap::new()),
            groups: RwLock::new(HashMap::new()),
            facts: RwLock::new(HashMap::new()),
            last_update: RwLock::new(0),
        }
    }

    /// Returns the singleton Arc<Cache>
    pub fn instance() -> Arc<Cache> {
        static INSTANCE: OnceLock<Arc<Cache>> = OnceLock::new();
        INSTANCE.get_or_init(|| Arc::new(Cache::new())).clone()
    }

    pub async fn init(pool: &sqlx::PgPool) {
        // Force creation of instance
        let _ = Cache::instance();

        // Consult database for initial state
        update_topology_cache(pool, true).await.unwrap();
    }

    pub async fn update_topology(&self, pool: &sqlx::Pool<sqlx::Postgres>, forced: bool) -> Result<(), rocket::http::Status>{
        update_topology_cache(pool, forced).await
    }

    /// Devices API
    pub async fn insert_device(&self, dev: Device) {
        let mut w = self.devices.write().await;
        w.insert(dev.device_id, dev);
        self.update_last().await;
    }

    pub async fn get_device(&self, id: i64) -> Option<Device> {
        let r = self.devices.read().await;
        r.get(&id).cloned()
    }

    pub async fn get_device_hostname(&self, id: i64) -> Option<String> {
        let r = self.devices.read().await;
        Some(r.get(&id)?.management_hostname.clone())
    }

    pub async fn has_device(&self, id: i64) -> bool {
        let r = self.devices.read().await;
        r.contains_key(&id)
    }

    pub async fn get_device_requested_metrics(&self, id: i64) -> Option<HashSet<String>>{

        let r = self.devices.read().await;
        Some(r.get(&id)?.configuration.requested_metrics.clone())
    }

    pub async fn get_device_id(&self, management_hostname: &str) -> Option<i64> {
        let r = self.devices.read().await;
        let d = r.iter().find(|(_, d)| d.management_hostname==management_hostname);
        if let Some((id, _)) = d {
            Some(id.clone())
        } 
        else {
            None
        }
    }


    pub async fn remove_device(&self, id: i64) -> Option<Device> {
        let mut w = self.devices.write().await;
        let removed = w.remove(&id);
        if removed.is_some() {
            self.update_last().await;
        }
        removed
    }

        pub async fn devices_json(&self) -> Result<String, serde_json::Error> {
        serialize_map(&self.devices).await
    }

    /// Links API
    pub async fn insert_link(&self, link: Link) {
        let mut w = self.links.write().await;
        w.insert(link.link_id, link);
        self.update_last().await;        
    }

    pub async fn get_link(&self, id: i64) -> Option<Link> {
        let r = self.links.read().await;
        r.get(&id).cloned()
    }

    pub async fn has_link(&self, id: i64) -> bool {
        let r = self.links.read().await;
        r.contains_key(&id)
    }

    pub async fn remove_link(&self, id: i64) -> Option<Link> {
        let mut w = self.links.write().await;
        let removed = w.remove(&id);
        if removed.is_some() {
            self.update_last().await;
        }
        removed
    }

    pub async fn links_json(&self) -> Result<String, serde_json::Error> {
        serialize_map(&self.links).await
    }

    /// Groups API
    pub async fn insert_group(&self, group: Group) {
        let mut w = self.groups.write().await;
        w.insert(group.group_id, group);
        self.update_last().await;
    }

    pub async fn get_group(&self, id: i64) -> Option<Group> {
        let r = self.groups.read().await;
        r.get(&id).cloned()
    }

    pub async fn get_group_members(&self, id: i64) -> Option<Vec<i64>> {
        let r = self.groups.read().await;
        Some(r.get(&id)?.members.clone()?)
    }

    pub fn get_group_device_ids(&self, id: i64) -> Option<HashSet<i64>> {
        let mut set: HashSet<i64> = {
            let d = self.devices.blocking_read();
            let g = self.groups.blocking_read();
            
            let members = g.get(&id)?.members.clone()?;
            let devices : HashSet<i64>= members.iter().filter(|id| d.contains_key(*id)).map(|id| *id).collect();
            devices
        };
        
        let inner_groups: HashSet<i64> = {
            let g = self.groups.blocking_read();
            let members = g.get(&id)?.members.clone().unwrap_or_default();
            let groups : HashSet<i64>= members.iter().filter(|id| g.contains_key(*id)).map(|id| *id).collect();
            groups
        };

        for group in inner_groups {
            let children = match self.get_group_device_ids(group) { Some(c) => c, None => continue };
            
            set.extend(children);
        }

        Some(set)
    }

    

    pub async fn has_group(&self, id: i64) -> bool {
        let r = self.groups.read().await;
        r.contains_key(&id)
    }

    pub async fn remove_group(&self, id: i64) -> Option<Group> {
        let mut w = self.groups.write().await;
        let removed = w.remove(&id);
        if removed.is_some() {
            self.update_last().await;
        }
        removed
    }

    pub async fn groups_json(&self) -> Result<String, serde_json::Error> {
        serialize_map(&self.groups).await
    }

    pub async fn get_evaluable_item(&self, id: i64) -> Option<EvaluableItem> {
        let r = self.devices.read().await;
        
        match r.get(&id) {
            Some(d) => Some(EvaluableItem::Device(d.clone())),
            None=> {
                let r = self.groups.read().await;
                match r.get(&id) {
                    Some(g) => Some(EvaluableItem::Group(g.clone())),
                    None => None
                }
            }
        }
    }

    // Cache API
    pub async fn get_facts(&self, management_hostname: &str, requested: &HashSet<String>) -> Option<HashMap<String, MetricValue>> {
        let r = self.facts.read().await;

        let extracted_facts: HashMap<String, MetricValue> = r.get(management_hostname)?
            .iter()
            .filter(|(key, _)| requested.contains(*key))
            .map(|(key, value)| (key.clone(), value.clone()))
            .collect();

        Some(extracted_facts)
    }

    // Update API
    pub async fn update_all(&self, devices: HashMap<i64, Device>, links: HashMap<i64, Link>, groups: HashMap<i64, Group>) {
        
        // Update devices
        let mut w = self.devices.write().await;
        w.clear();
        w.extend(devices);
        
        // Update links
        let mut w = self.links.write().await;
        w.clear();
        w.extend(links);
        

        // Update groups
        let mut w = self.groups.write().await;
        w.clear();
        w.extend(groups);
    }

    pub async fn update_facts(&self, metrics: Metrics) {
        let mut w = self.facts.write().await;
        w.clear();
        w.extend(metrics);
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
        let interval_secs = Config::instance().get_value_opt ("backend/controller/cache/cache_invalidation_s", "/").unwrap_or_default().as_u64().unwrap_or(60);

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

    pub fn current_epoch_secs() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    }

    /// Clear everything (example helper)
    pub async fn clear(&self) {
        self.devices.write().await.clear();
        self.links.write().await.clear();
        self.groups.write().await.clear();
        self.update_last().await;
    }

    pub async fn as_json(&self) -> Result<String, serde_json::Error> {
        let devices = self.devices.read().await;
        let links = self.links.read().await;
        let groups = self.groups.read().await;

        let value = serde_json::json!({
            "devices": &*devices,
            "links": &*links,
            "groups": &*groups,
        });

        serde_json::to_string(&value)
    }

    pub async fn icmp_inventory(&self) -> Vec<String> {
        self.devices.read().await
            .values()
            .filter(|d| d.configuration.data_sources.contains(&DataSource::Icmp))
            .map(|d| d.management_hostname.as_str().to_string())
            .collect::<Vec<String>>()
    }

    pub async fn ansible_inventory(&self) -> Vec<String> {
        self.devices.read().await
            .values()
            .filter(|d| d.configuration.data_sources.contains(&DataSource::Icmp))
            .map(|d| d.management_hostname.as_str().to_string())
            .collect::<Vec<String>>()
            
    }

}