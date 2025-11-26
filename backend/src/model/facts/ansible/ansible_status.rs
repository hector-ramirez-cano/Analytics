use std::fmt;
use serde::{Deserialize, Deserializer, Serialize, Serializer, de};
use serde::ser::SerializeStruct;

/// Ansible status codes
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AnsibleStatus {
    Reachable,
    Skipped(String),
    Dark(String),
    Unknown(String),
}


impl Default for AnsibleStatus {
    fn default() -> Self {
        AnsibleStatus::Unknown(String::new())
    }
}

impl AnsibleStatus {
    /// Convert from integer code to enum
    pub fn from_i32(code: i32) -> Self {
        match code {
            1 => AnsibleStatus::Reachable,
            0 => AnsibleStatus::Skipped(String::new()),
            2 => AnsibleStatus::Dark(String::new()),
            _ => AnsibleStatus::Unknown(String::new()),
        }
    }

    /// Convert enum back to integer code
    pub fn to_i32(self) -> i32 {
        match self {
            AnsibleStatus::Skipped(_) => 0,
            AnsibleStatus::Reachable => 1,
            AnsibleStatus::Dark(_) => 2,
            AnsibleStatus::Unknown(_) => -1,
        }
    }

    pub fn merge(&mut self, other: &AnsibleStatus) {
        if matches!(self, AnsibleStatus::Unknown(_)) {
            *self = other.clone();
        }
    }
}

/// Implement Display so it prints like the Python __str__ method
impl fmt::Display for AnsibleStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            AnsibleStatus::Skipped(_) => "SKIPPED",
            AnsibleStatus::Reachable => "REACHABLE",
            AnsibleStatus::Dark(_) => "DARK",
            AnsibleStatus::Unknown(_) => "UNKNOWN",
        };
        write!(f, "{}", s)
    }
}

impl Serialize for AnsibleStatus {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut s = serializer.serialize_struct("AnsibleStatus", 2)?;
        match self {
            AnsibleStatus::Reachable => {
                s.serialize_field("status", "reachable")?;
                s.serialize_field("msg", "")?;
            }
            AnsibleStatus::Skipped(msg) => {
                s.serialize_field("status", "skipped")?;
                s.serialize_field("msg", msg)?;
            }
            AnsibleStatus::Dark(msg) => {
                s.serialize_field("status", "dark")?;
                s.serialize_field("msg", msg)?;
            }
            AnsibleStatus::Unknown(msg) => {
                s.serialize_field("status", "unknown")?;
                s.serialize_field("msg", msg)?;
            }
        }
        s.end()
    }
}

impl<'de> Deserialize<'de> for AnsibleStatus {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        struct Helper {
            status: String,
            #[serde(default)]
            msg: String,
        }

        let h = Helper::deserialize(deserializer)?;
        match h.status.as_str() {
            "reachable" => Ok(AnsibleStatus::Reachable),
            "skipped" => Ok(AnsibleStatus::Skipped(h.msg)),
            "dark" => Ok(AnsibleStatus::Dark(h.msg)),
            "unknown" => Ok(AnsibleStatus::Unknown(h.msg)),
            other => Err(de::Error::unknown_variant(other, &["reachable","skipped","dark","unknown"])),
        }
    }
}