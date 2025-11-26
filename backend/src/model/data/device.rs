use std::collections::HashMap;
use std::hash::{Hash, Hasher};

use serde::{Deserialize, Serialize};

use crate::model::data::device_configuration::DeviceConfiguration;
use crate::model::data::device_state::DeviceStatus;
use crate::types::DeviceId;

#[derive(Debug)]
pub enum DeviceError {
    MissingField(&'static str),
    InvalidType(&'static str),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Device {
    #[serde (rename = "id")]
    pub device_id: DeviceId,

    #[serde (rename = "name")]
    pub device_name: String,

    #[serde (rename = "latitude")]
    pub latitude: f64,

    #[serde (rename = "longitude")]
    pub longitude: f64,

    #[serde (rename = "management-hostname")]
    pub management_hostname: String,

    #[serde (rename = "configuration")]
    pub configuration: DeviceConfiguration,

    #[serde (rename = "state", default)]
    pub state: DeviceStatus,
}

impl Device {
    pub fn new(
        device_id: DeviceId,
        device_name: String,
        latitude: f64,
        longitude: f64,
        management_hostname: String,
        configuration: DeviceConfiguration,
    ) -> Self {
        Self {
            device_id,
            device_name,
            latitude,
            longitude,
            management_hostname,
            configuration,
            state: DeviceStatus::default()
        }
    }
    pub fn to_dict(&self) -> HashMap<String, serde_json::Value> {
        let mut map = HashMap::new();
        map.insert("id".to_string(), serde_json::json!(self.device_id));
        map.insert("name".to_string(), serde_json::json!(self.device_name));
        map.insert("latitude".to_string(),serde_json::json!(self.latitude));
        map.insert("latitude".to_string(),serde_json::json!(self.latitude));
        map.insert(
            "management-hostname".to_string(),
            serde_json::json!(self.management_hostname),
        );
        // map.insert("status".to_string(), serde_json::json!(self.state.to_json_str()));
        // map.insert("metadata".to_string(), serde_json::json!(self.metadata));
        map.insert(
            "configuration".to_string(),
            serde_json::json!(self.configuration.to_dict()),
        );
        map
    }
}

impl PartialEq for Device {
    fn eq(&self, other: &Self) -> bool {
        self.device_id == other.device_id
            && self.device_name == other.device_name
            && (self.latitude - other.latitude).abs() < 1e-6
            && (self.longitude - other.longitude).abs() < 1e-6
            && self.management_hostname == other.management_hostname
    }
}

impl Eq for Device {}

impl Hash for Device {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.device_id.hash(state);
        self.device_name.hash(state);

        let lat = (self.latitude * 1_000_000.0).round() as i64;
        lat.hash(state);

        let lon = (self.longitude * 1_000_000.0).round() as i64;
        lon.hash(state);

        self.management_hostname.hash(state);
        // configuration.hash(state); // if DeviceConfiguration implements Hash
    }
}

