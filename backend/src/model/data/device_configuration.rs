use std::collections::{HashMap, HashSet};
use std::hash::{Hash, Hasher};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::model::data::DataSource;


/// A configuration for a device – the exact same shape as the Python dataclass.
///
/// * `data_sources`          – set of data‑source identifiers  
/// * `available_values`      – set of values that the device can provide  
/// * `requested_metadata`    – metadata keys requested by the caller  
/// * `requested_metrics`     – metric names requested by the caller
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct DeviceConfiguration {
    #[serde(rename = "data-sources")]
    pub data_sources: HashSet<DataSource>,

    #[serde(rename = "available-values")]
    pub available_values: HashSet<String>,

    #[serde(rename = "requested-metadata")]
    pub requested_metadata: HashSet<String>,

    #[serde(rename = "requested-metrics")]
    pub requested_metrics: HashSet<String>,
}

impl DeviceConfiguration {
    /// Convert the struct into a plain `serde_json::Value` that mirrors the
    /// dictionary returned by the Python implementation.
    ///
    /// Example output:
    /// ```json
    /// {
    ///     "data-sources": ["src1", "src2"],
    ///     "available-values": ["v1", "v2"],
    ///     "requested-metadata": ["m1"],
    ///     "requested-metrics": ["metric1"]
    /// }
    /// ```
    pub fn to_dict(&self) -> Value {
        json!({
            "data-sources": self.data_sources.iter().cloned().collect::<Vec<_>>(),
            "available-values": self.available_values.iter().cloned().collect::<Vec<_>>(),
            "requested-metadata": self.requested_metadata.iter().cloned().collect::<Vec<_>>(),
            "requested-metrics": self.requested_metrics.iter().cloned().collect::<Vec<_>>(),
        })
    }

    /// Build a `DeviceConfiguration` from the structure that the Python
    /// `from_dict` expects – i.e. a map containing a single key `"configuration"`
    /// whose value is another map with the four fields.
    ///
    /// Returns `None` if the expected shape isn’t found or any of the inner
    /// collections can’t be converted to a `HashSet<String>`.
    pub fn from_dict(map: &HashMap<String, serde_json::Value>) -> Option<Self> {
        let cfg = map.get("configuration")?;
        Some(DeviceConfiguration {
            data_sources: cfg
                .get("data-sources")
                .and_then(|v| v.as_array())
                .map_or_else(HashSet::new, |arr| {
                    arr.iter()
                        .map(|x| DataSource::from(x.as_str()))
                        .collect()
                }),
            available_values: cfg
                .get("available-values")
                .and_then(|v| v.as_array())
                .map_or_else(HashSet::new, |arr| {
                    arr.iter()
                        .filter_map(|x| x.as_str().map(str::to_string))
                        .collect()
                }),
            requested_metadata: cfg
                .get("requested-metadata")
                .and_then(|v| v.as_array())
                .map_or_else(HashSet::new, |arr| {
                    arr.iter()
                        .filter_map(|x| x.as_str().map(str::to_string))
                        .collect()
                }),
            requested_metrics: cfg
                .get("requested-metrics")
                .and_then(|v| v.as_array())
                .map_or_else(HashSet::new, |arr| {
                    arr.iter()
                        .filter_map(|x| x.as_str().map(str::to_string))
                        .collect()
                }),
        })
    }
}

impl Hash for DeviceConfiguration {
    fn hash<H: Hasher>(&self, state: &mut H) {
        // hash other fields first if present...
        let mut v: Vec<&DataSource> = self.data_sources.iter().collect();
        v.sort_unstable();
        for s in v {
            s.hash(state);
        }
        
        let mut v: Vec<&String> = self.available_values.iter().collect();
        v.sort_unstable();
        for s in v {
            s.hash(state);
        }

        let mut v: Vec<&String> = self.requested_metadata.iter().collect();
        v.sort_unstable();
        for s in v {
            s.hash(state);
        }

        let mut v: Vec<&String> = self.requested_metrics.iter().collect();
        v.sort_unstable();
        for s in v {
            s.hash(state);
        }
    }
}