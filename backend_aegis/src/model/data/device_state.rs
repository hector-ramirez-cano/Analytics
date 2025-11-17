use std::collections::HashMap;
use std::fmt;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::model::facts::ansible::ansible_status::AnsibleStatus;
use crate::model::facts::icmp::icmp_status::IcmpStatus;
use crate::model::facts::snmp::snmp_status::SnmpStatus;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceStatus {
    #[serde(rename="ansible")]
    pub ansible_status: AnsibleStatus,

    #[serde(rename="icmp")]
    pub icmp_status: IcmpStatus,

    #[serde(rename="snmp")]
    pub snmp_status: SnmpStatus,
}


impl DeviceStatus {
    pub fn new(
        ansible_status: AnsibleStatus,
        icmp_status: IcmpStatus,
        snmp_status: SnmpStatus,
    ) -> Self {
        Self {
            ansible_status: ansible_status,
            icmp_status: icmp_status,
            snmp_status: snmp_status,
        }
    }


    pub fn new_ansible(ansible_status: AnsibleStatus) -> Self {
        Self {
            ansible_status,
            ..Default::default()
        }
    }

    pub fn new_icmp(icmp_status: IcmpStatus) -> Self {
        Self {
            icmp_status,
            ..Default::default()
        }
    }

    pub fn new_snmp(snmp_status: SnmpStatus) -> Self {
        Self {
            snmp_status,
            ..Default::default()
        }
    }

    pub fn empty() -> Self {
        Self {
            ansible_status: AnsibleStatus::Unknown(String::new()),
            icmp_status   : IcmpStatus::Unknown(String::new()),
            snmp_status   : SnmpStatus::Unknown,
        }
    }

    pub fn merge(&mut self, other : DeviceStatus) {

        // Overwrite only if not unknown
        match other.ansible_status {
            AnsibleStatus::Unknown(_) => {},
                AnsibleStatus::Reachable
            |   AnsibleStatus::Skipped(_)
            |   AnsibleStatus::Dark(_) => self.ansible_status = other.ansible_status
        };

        match other.icmp_status {
            IcmpStatus::Unknown(_) => {},
                IcmpStatus::Reachable
            |   IcmpStatus::Unreachable(_)
            |   IcmpStatus::Timeout(_)
            |   IcmpStatus::HostNotFound(_)
            |   IcmpStatus::NameResolutionError(_) => self.icmp_status = other.icmp_status,
        };

        match other.snmp_status {
            SnmpStatus::Unknown => self.snmp_status = self.snmp_status,
        }
    }

    /// Safe conversion from JSON-like dict
    pub fn make_from_dict(status: &HashMap<String, Value>) -> Result<Self, String> {
        let ansible = status.get("ansible_status").and_then(|v| v.as_object()).cloned().unwrap_or_default();
        let icmp    = status.get("icmp_status").and_then(|v| v.as_object()).cloned().unwrap_or_default();
        let snmp    = status.get("snmp_status").and_then(|v| v.as_object()).cloned().unwrap_or_default();

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

        Ok(DeviceStatus::new(ansible_status, icmp_status, snmp_status))
    }

    pub fn to_json_map(&self) -> HashMap<String, Value> {
        let mut map = HashMap::new();
        map.insert("ansible_status".to_string(), Value::String(self.ansible_status.to_string()));
        map.insert("icmp_status".to_string(), Value::String(self.icmp_status.to_string()));
        map.insert("snmp_status".to_string(), Value::String(self.snmp_status.to_string()));
        map
    }
}

impl fmt::Display for DeviceStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Equivalent of Python's __str__
        write!(
            f,
            "{}, {}, {}",
            self.ansible_status,
            self.icmp_status,
            self.snmp_status,
        )
    }
}

impl Default for DeviceStatus {
    fn default() -> Self {
        Self { ansible_status: AnsibleStatus::Unknown(String::default()), icmp_status: IcmpStatus::Unknown(String::default()), snmp_status: SnmpStatus::Unknown }
    }
}