use std::collections::{HashMap, HashSet};
use std::fmt;

use ordered_float::OrderedFloat;
use influxdb2::models::FieldValue;
use serde::{Deserialize, Deserializer, Serialize, Serializer, de, ser::SerializeSeq};

use crate::model::data::device_state::DeviceStatus;

pub type AlertId = i64;
pub type AlertEventId = i64;
pub type AlertRuleId = i64;
pub type AlertAckActor = i64;
pub type AlertTargetId = i64;

pub type ItemId = i64;
pub type EvaluableItemId = i64;
pub type DeviceId = ItemId;
pub type LinkId = ItemId;
pub type GroupId = ItemId;

pub type SyslogMessageId = i64;

pub type DashboardId = i64;

pub type EpochSeconds = u64;

pub type TelegramTypeId = i64;

/// Holds the device Hostname. For clarity purposes
pub type DeviceHostname = String;

/// Holds the metric name. For clarity purposes
pub type MetricName = String;

/// Holds the exposed fields a given device returned via Fact Gathreing
pub type ExposedFields = HashSet<MetricName>;

/// Contains all the recovered metrics for a given device, in order of metric -> metricValue
pub type MetricSet = HashMap<MetricName, MetricValue>;

/// Contains all the recovered metrics for all the devices, in the order of device -> MetricSet
pub type Metrics = HashMap<DeviceHostname, MetricSet>;

/// Contains the status for all the given device status, in the order of device -> Status
pub type Status: = HashMap<DeviceHostname, DeviceStatus>;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum MetricValue{
    String(String),
    Number(OrderedFloat<f64>),
    Integer(i64),
    Boolean(bool),
    Array(Vec<MetricValue>),
    Null(),
}

impl Default for MetricValue {
    fn default() -> Self {
        MetricValue::Null()
    }
}

impl Serialize for MetricValue {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match self {
            MetricValue::String(s) => serializer.serialize_str(s),
            MetricValue::Number(n) => serializer.serialize_f64(**n),
            MetricValue::Integer(i) => serializer.serialize_i64(*i),
            MetricValue::Boolean(b) => serializer.serialize_bool(*b),
            MetricValue::Array(arr) => {
                let mut seq = serializer.serialize_seq(Some(arr.len()))?;
                for item in arr {
                    seq.serialize_element(item)?;
                }
                seq.end()
            }
            MetricValue::Null() => serializer.serialize_unit(),
        }
    }
}

impl<'de> Deserialize<'de> for MetricValue {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where D: Deserializer<'de> {
        let v = serde_json::Value::deserialize(deserializer)?;
        Ok(match v {
            serde_json::Value::String(s) => MetricValue::String(s),
            serde_json::Value::Number(num) => {
                if let Some(i) = num.as_i64() {
                    MetricValue::Integer(i)
                } else if let Some(f) = num.as_f64() {
                    MetricValue::Number(OrderedFloat(f))
                } else {
                    return Err(de::Error::custom("invalid number"));
                }
            }
            serde_json::Value::Bool(b) => MetricValue::Boolean(b),
            serde_json::Value::Array(arr) => {
                MetricValue::Array(arr.into_iter().map(|x| {
                    serde_json::from_value::<MetricValue>(x)
                        .map_err(|_| de::Error::custom("invalid array element"))
                }).collect::<Result<Vec<_>, _>>()?)
            }
            serde_json::Value::Null => MetricValue::Null(),
            serde_json::Value::Object(_) => {
                return Err(de::Error::custom("objects not supported in MetricValue"));
            }
        })
    }
}

impl Into<serde_json::Value> for MetricValue {
    fn into(self) -> serde_json::Value {
        match self {
            MetricValue::String(v) => serde_json::json!(v),
            MetricValue::Number(v)    => serde_json::json!(*v),
            MetricValue::Integer(v)   => serde_json::json!(v),
            MetricValue::Boolean(v)  => serde_json::json!(v),
            MetricValue::Array(metric_values) => serde_json::json!(metric_values),
            MetricValue::Null() => serde_json::Value::Null,
        }
    }
}

impl Into<MetricValue> for serde_json::Value {
    fn into(self) -> MetricValue {
        match self {
            serde_json::Value::Null => MetricValue::Null(),
            serde_json::Value::Bool(b) => MetricValue::Boolean(b),
            serde_json::Value::Number(number) => MetricValue::Number(number.as_f64().unwrap_or(0.0).into()),
            serde_json::Value::String(s) => MetricValue::String(s),
            serde_json::Value::Array(values) => MetricValue::Array(values.iter().map(|v| { let v : MetricValue = v.clone().into(); v}).collect()),
            serde_json::Value::Object(_) => MetricValue::Null(),
        }
    }
}

impl fmt::Display for MetricValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MetricValue::String(s) => write!(f, "\"{}\"", s),
            MetricValue::Number(n) => write!(f, "{}", n),
            MetricValue::Integer(i) => write!(f, "{}", i),
            MetricValue::Boolean(b) => write!(f, "{}", b),
            MetricValue::Array(arr) => {
                write!(f, "[")?;
                for (i, val) in arr.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{}", val)?;
                }
                write!(f, "]")
            }
            MetricValue::Null() => write!(f, "null"),
        }
    }
}

impl Into<FieldValue> for MetricValue {
    fn into(self) -> FieldValue {
        match self {
            MetricValue::String(m) => FieldValue::String(m),
            MetricValue::Number(m) => FieldValue::F64(*m),
            MetricValue::Integer(m) => FieldValue::I64(m),
            MetricValue::Boolean(m) => FieldValue::Bool(m),
            MetricValue::Array(_) => FieldValue::String("Unsupported type".to_string()),
            MetricValue::Null() => FieldValue::String("Unsupported type".to_string()),
        }
    }
}
