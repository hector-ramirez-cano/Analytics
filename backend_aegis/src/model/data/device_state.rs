use std::collections::HashMap;
use std::fmt;
use serde_json::Value;

use crate::model::facts::ansible::ansible_status::AnsibleStatus;
use crate::model::facts::icmp::icmp_status::IcmpStatus;
use crate::model::facts::snmp::snmp_status::SnmpStatus;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeviceState {
    Skipped,
    Reachable,
    Dark,
    Unknown,
}

impl Default for DeviceState {
    fn default() -> Self {
        DeviceState::Unknown
    }
}

impl DeviceState {
    pub fn from_i32(code: i32) -> Self {
        match code {
            0 => DeviceState::Skipped,
            1 => DeviceState::Reachable,
            2 => DeviceState::Dark,
            _ => DeviceState::Unknown,
        }
    }

    pub fn to_i32(self) -> i32 {
        match self {
            DeviceState::Skipped => 0,
            DeviceState::Reachable => 1,
            DeviceState::Dark => 2,
            DeviceState::Unknown => -1,
        }
    }
}

impl fmt::Display for DeviceState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            DeviceState::Skipped => "SKIPPED",
            DeviceState::Reachable => "REACHABLE",
            DeviceState::Dark => "DARK",
            DeviceState::Unknown => "UNKNOWN",
        };
        write!(f, "{}", s)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct DeviceStatus {
    pub ansible_status: AnsibleStatus,
    pub icmp_status: IcmpStatus,
    pub snmp_status: SnmpStatus,
    pub msg: HashMap<String, String>,
}

impl DeviceStatus {
    pub fn new(
        ansible_status: AnsibleStatus,
        icmp_status: IcmpStatus,
        snmp_status: SnmpStatus,
        msg: HashMap<String, String>,
    ) -> Self {
        Self {
            ansible_status,
            icmp_status,
            snmp_status,
            msg,
        }
    }

    pub fn empty() -> Self {
        Self { 
            ansible_status: AnsibleStatus::Unknown(String::new()),
            icmp_status: IcmpStatus::Unknown(String::new()),
            snmp_status: SnmpStatus::Unknown,
            msg: HashMap::new()
        }
    }

    /// Safe conversion from JSON-like dict
    pub fn make_from_dict(status: &HashMap<String, Value>) -> Result<Self, String> {
        let ansible = status.get("ansible_status").and_then(|v| v.as_object()).cloned().unwrap_or_default();
        let icmp    = status.get("icmp_status").and_then(|v| v.as_object()).cloned().unwrap_or_default();
        let snmp    = status.get("snmp_status").and_then(|v| v.as_object()).cloned().unwrap_or_default();

        let mut msg = HashMap::new();
        msg.insert("ansible".to_string(), ansible.get("msg").and_then(|v| v.as_str()).unwrap_or("").to_string());
        msg.insert("icmp".to_string(), icmp.get("msg").and_then(|v| v.as_str()).unwrap_or("").to_string());
        msg.insert("snmp".to_string(), snmp.get("msg").and_then(|v| v.as_str()).unwrap_or("").to_string());

        let ansible_status = ansible.get("status")
            .and_then(|v| v.as_i64())
            .map(|c| AnsibleStatus::from_i32(c as i32))
            .unwrap_or(AnsibleStatus::Unknown(String::new()));

        let icmp_status = icmp.get("status")
            .and_then(|v| v.as_i64())
            .map(|c| IcmpStatus::from_i32(c as i32))
            .unwrap_or(IcmpStatus::Unknown(String::new()));

        let snmp_status = snmp.get("status")
            .and_then(|v| v.as_i64())
            .map(|c| SnmpStatus::from_i32(c as i32))
            .unwrap_or(SnmpStatus::Unknown);

        Ok(DeviceStatus::new(ansible_status, icmp_status, snmp_status, msg))
    }

    pub fn to_json_map(&self) -> HashMap<String, Value> {
        let mut map = HashMap::new();
        map.insert("ansible_status".to_string(), Value::String(self.ansible_status.to_string()));
        map.insert("icmp_status".to_string(), Value::String(self.icmp_status.to_string()));
        map.insert("snmp_status".to_string(), Value::String(self.snmp_status.to_string()));
        map.insert("msg".to_string(), serde_json::json!(self.msg));
        map
    }
}

impl fmt::Display for DeviceStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Equivalent of Python's __str__
        write!(
            f,
            "{}, {}, {}, {:?}",
            self.ansible_status,
            self.icmp_status,
            self.snmp_status,
            self.msg
        )
    }
}
