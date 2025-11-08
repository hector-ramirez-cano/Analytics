use std::collections::HashMap;
use std::hash::{Hash, Hasher};

use serde::{Deserialize, Serialize};

use crate::model::data::device_configuration::DeviceConfiguration;

#[derive(Debug)]
pub enum DeviceError {
    MissingField(&'static str),
    InvalidType(&'static str),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Device {
    #[serde (rename = "id")]
    pub device_id: i64,

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
}

impl Device {
    pub fn new(
        device_id: i64,
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

    /*
    pub fn eval_rule<'a>(
        &'a self,
        rule: &AlertRule,
        d: &HashMap<String, HashMap<String, serde_json::Value>>,
        _get_item_fn: fn(),
    ) -> (bool, (&'a Device,)) {
        let data = d.get(&self.management_hostname).unwrap_or(&HashMap::new());
        (rule.eval(data), (self,))
    }

    pub fn which_eval_raised(
        &self,
        rule: &AlertRule,
        d: &HashMap<String, HashMap<String, serde_json::Value>>,
    ) -> Vec<(String, String)> {
        let data = d.get(&self.management_hostname).unwrap_or(&HashMap::new());
        rule.raising_values(data)
    }

    */
    pub fn from_dict(d: &HashMap<String, serde_json::Value>) -> Result<Self, DeviceError> {
        let device_id = d.get("id")
            .and_then(|v| v.as_i64())
            .ok_or(DeviceError::MissingField("id"))?;

        let device_name = d.get("name")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()).ok_or(DeviceError::MissingField("name"))?;

        let coords = d.get("coordinates")
            .and_then(|v| v.as_array())
            .ok_or(DeviceError::MissingField("coordinates"))?;
        if coords.len() < 2 {
            return Err(DeviceError::InvalidType("coordinates"));
        }

        let geocoords = d.get("geocoordinates")
            .and_then(|v| v.as_array())
            .ok_or(DeviceError::MissingField("geocoordinates"))?;
        if geocoords.len() < 2 {
            return Err(DeviceError::InvalidType("geocoordinates"));
        }
        let latitude = geocoords[0].as_f64().ok_or(DeviceError::InvalidType("geocoordinates[0]"))?;
        let longitude = geocoords[1].as_f64().ok_or(DeviceError::InvalidType("geocoordinates[1]"))?;

        let management_hostname = d.get("management-hostname")
            .and_then(|v| v.as_str())
            .ok_or(DeviceError::MissingField("management-hostname"))?
            .to_string();

        let configuration = DeviceConfiguration::from_dict(d).unwrap_or_default();

        Ok(Self {
            device_id,
            device_name,
            latitude,
            longitude,
            management_hostname,
            configuration,
        })
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

