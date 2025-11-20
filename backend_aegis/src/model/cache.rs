use std::collections::{HashMap, HashSet, VecDeque};
use std::time::{SystemTime, UNIX_EPOCH};
use std::sync::{Arc, OnceLock};
use tokio::sync::{RwLock, RwLockWriteGuard};


use serde::Serialize;

use crate::AegisError;
use crate::config::Config;
use crate::alerts::EvaluableItem;
use crate::model::data::DataSource;
use crate::model::data::device::Device;
use crate::model::data::device_state::DeviceStatus;
use crate::model::data::link::Link;
use crate::model::data::group::Group;
use crate::model::db::update_topology::update_topology_cache;
use crate::model::facts::fact_gathering_backend::FactMessage;
use crate::types::{DeviceId, EpochSeconds, EvaluableItemId, GroupId, ItemId, LinkId, ExposedFields, MetricValue};

async fn serialize_map<T: Serialize>(lock: &RwLock<HashMap<i64, T>>) -> Result<String, serde_json::Error> {
    serde_json::to_string(&*lock.read().await)
}

pub struct Cache {
    pub facts: RwLock<FactMessage>,
    devices: RwLock<HashMap<DeviceId, Device>>,
    links: RwLock<HashMap<LinkId, Link>>,
    groups: RwLock<HashMap<GroupId, Group>>,
    last_update: RwLock<EpochSeconds>, // epoch seconds
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

    pub async fn update_topology(&self, pool: &sqlx::Pool<sqlx::Postgres>, forced: bool) -> Result<(), AegisError>{
        update_topology_cache(pool, forced).await
    }

    /// Devices API
    pub async fn insert_device(&self, dev: Device) {
        let mut w = self.devices.write().await;
        w.insert(dev.device_id, dev);
        self.update_last_update().await;
    }

    pub async fn get_device(&self, id: DeviceId) -> Option<Device> {
        let r = self.devices.read().await;
        r.get(&id).cloned()
    }

    pub async fn get_device_hostname(&self, id: DeviceId) -> Option<String> {
        let r = self.devices.read().await;

        Some(r.get(&id)?.management_hostname.clone())
    }

    pub async fn get_device_hostnames(&self) -> Option<HashMap<DeviceId, String>> {
        let r = self.devices.read().await;

        let map = r.iter().map(|(id, device)| (id.clone(), device.management_hostname.clone())).collect();
        Some(map)
    }

    pub async fn has_device(&self, id: DeviceId) -> bool {
        let r = self.devices.read().await;
        r.contains_key(&id)
    }

    pub async fn get_device_requested_metrics(&self, id: DeviceId) -> Option<HashSet<String>>{

        let r = self.devices.read().await;
        Some(r.get(&id)?.configuration.requested_metrics.clone())
    }

    pub async fn get_device_id(&self, management_hostname: &str) -> Option<DeviceId> {
        let r = self.devices.read().await;
        let d = r.iter().find(|(_, d)| d.management_hostname==management_hostname);
        if let Some((id, _)) = d {
            Some(id.clone())
        }
        else {
            None
        }
    }

    pub async fn set_device_status(&self, id: DeviceId, status : &DeviceStatus, exposed_fields: &ExposedFields) {
        let mut w = self.devices.write().await;

        if let Some(device) = w.get_mut(&id) {
            device.state = status.clone();
            device.configuration.available_values = exposed_fields.clone();
        }
    }


    pub async fn remove_device(&self, id: DeviceId) -> Option<Device> {
        let mut w = self.devices.write().await;
        let removed = w.remove(&id);
        if removed.is_some() {
            self.update_last_update().await;
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
        self.update_last_update().await;
    }

    pub async fn get_link(&self, id: LinkId) -> Option<Link> {
        let r = self.links.read().await;
        r.get(&id).cloned()
    }

    pub async fn has_link(&self, id: LinkId) -> bool {
        let r = self.links.read().await;
        r.contains_key(&id)
    }

    pub async fn remove_link(&self, id: LinkId) -> Option<Link> {
        let mut w = self.links.write().await;
        let removed = w.remove(&id);
        if removed.is_some() {
            self.update_last_update().await;
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
        self.update_last_update().await;
    }

    pub async fn get_group(&self, id: GroupId) -> Option<Group> {
        let r = self.groups.read().await;
        r.get(&id).cloned()
    }

    pub async fn get_group_members(&self, id: GroupId) -> Option<Vec<ItemId>> {
        let r = self.groups.read().await;
        Some(r.get(&id)?.members.clone()?)
    }

    // TODO: Enforce no loops are held for any given group. Db already enforces this, but the backend should enforce this also, just in case
    /// Recursively iterates into inner groups to get the device ids that are held within this group and this group's subgroups
    pub async fn get_group_device_ids(&self, id: GroupId) -> Option<HashSet<DeviceId>> {
        // quick existence check for the start group (match original behavior)
        {
            let g = self.groups.read().await;
            if !g.contains_key(&id) {
                return None;
            }
        }

        let mut visited: HashSet<GroupId> = HashSet::new();
        let mut result_devices: HashSet<DeviceId> = HashSet::new();
        let mut stack: VecDeque<GroupId> = VecDeque::new();

        // seed with the starting group id
        visited.insert(id);
        stack.push_back(id);

        while let Some(gid) = stack.pop_back() {
            // grab the members for this group and a snapshot of the devices map for lookups
            let members_opt = {
                let g = self.groups.read().await;
                g.get(&gid).and_then(|gi| gi.members.clone())
            };

            let devices_map = self.devices.read().await;

            let members = match members_opt {
                Some(m) => m,
                None => continue, // group has no members or disappeared; skip
            };

            for member_id in members.iter() {
                // if member is a device, add to result
                if devices_map.contains_key(member_id) {
                    result_devices.insert(*member_id);
                    continue;
                }

                // otherwise, if member is a group and not visited, enqueue it
                {
                    let g = self.groups.read().await;
                    if g.contains_key(member_id) && !visited.contains(member_id) {
                        visited.insert(*member_id);
                        stack.push_back(*member_id);
                    }
                }
            }
            // devices_map lock dropped here (end of scope)
        }

        Some(result_devices)
    }

    pub async fn has_group(&self, id: GroupId) -> bool {
        let r = self.groups.read().await;
        r.contains_key(&id)
    }

    pub async fn remove_group(&self, id: GroupId) -> Option<Group> {
        let mut w = self.groups.write().await;
        let removed = w.remove(&id);
        if removed.is_some() {
            self.update_last_update().await;
        }
        removed
    }

    pub async fn groups_json(&self) -> Result<String, serde_json::Error> {
        serialize_map(&self.groups).await
    }

    pub async fn get_evaluable_item(&self, id: EvaluableItemId) -> Option<EvaluableItem> {
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
            .metrics
            .iter()
            .filter(|(key, _)| requested.contains(*key))
            .map(|(key, value)| (key.clone(), value.clone()))
            .collect();

        Some(extracted_facts)
    }

    // Update API
    pub async fn update_all(&self, devices: HashMap<DeviceId, Device>, links: HashMap<LinkId, Link>, groups: HashMap<GroupId, Group>) {

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

    pub async fn update_facts(&self, facts: FactMessage) {
        let mut w = self.facts.write().await;
        w.clear();
        w.extend(facts);
    }



    /// Last update (epoch seconds)
    pub async fn last_update(&self) -> EpochSeconds {
        let guard = self.last_update.read().await;
        *guard
    }

    /// Updates the last_update variable to the current time since EPOCH
    async fn update_last_update(&self) {
        let now: EpochSeconds = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs().into();
        let mut w: RwLockWriteGuard<'_, EpochSeconds> = self.last_update.write().await;
        *w = now;
    }

    /// Try to claim the update. If this returns Some(write_guard) the caller won the right
    /// to update and holds the write lock on `last_update`. Caller should perform the
    /// refresh while holding the guard and then drop it when done.
    ///
    /// Returns None if an update is not needed (someone else updated recently).
    pub async fn try_claim_update(&self, forced: bool) -> Option<RwLockWriteGuard<'_, EpochSeconds>> {
        let interval_secs: EpochSeconds = Config::instance().get_value_opt ("backend/controller/cache/cache_invalidation_s", "/").unwrap_or_default().as_u64().unwrap_or(60).into();

        // fast read-only check
        let now: EpochSeconds = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0).into();

        // if the update isn't due, and the caller didn't request a forced update
        let last: EpochSeconds = *self.last_update.read().await;
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

    pub fn current_epoch_secs() -> EpochSeconds {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0).into()
    }

    pub async fn as_json(&self) -> Result<serde_json::Value, AegisError> {
        let devices = self.devices.read().await;
        let links = self.links.read().await;
        let groups = self.groups.read().await;

        let device_vec: Vec<&Device> = devices.values().collect();
        let link_vec: Vec<&Link> = links.values().collect();
        let group_vec: Vec<&Group> = groups.values().collect();

        Ok(serde_json::json!({
            "devices": &*device_vec,
            "links": &*link_vec,
            "groups": &*group_vec,
        }))
    }

    pub async fn icmp_inventory(&self) -> Vec<String> {
        self.devices.read().await
            .values()
            .filter(|d| d.configuration.data_sources.contains(&DataSource::Icmp))
            .map(|d| d.management_hostname.as_str().to_string())
            .collect::<Vec<String>>()
    }

    pub async fn snmp_inventory(&self) -> Vec<String> {
        self.devices.read().await
            .values()
            .filter(|d| d.configuration.data_sources.contains(&DataSource::Snmp))
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