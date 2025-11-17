use serde::{Serialize, Deserialize, Serializer, Deserializer};
use serde::ser::SerializeStruct;
use serde::de::{self};
use std::fmt;


/// SNMP status codes
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SnmpStatus {
    Unknown,
}

impl Default for SnmpStatus {
    fn default() -> Self {
        SnmpStatus::Unknown
    }
}

impl SnmpStatus {
    /// Convert from integer code to enum
    pub fn from_i32(code: i32) -> Self {
        match code {
            -1 => SnmpStatus::Unknown,
            _ => SnmpStatus::Unknown, // default fallback
        }
    }

    /// Convert enum back to integer code
    pub fn to_i32(self) -> i32 {
        match self {
            SnmpStatus::Unknown => -1,
        }
    }

    pub fn merge(&mut self, other: &SnmpStatus) {
        if matches!(self, SnmpStatus::Unknown) {
            *self = other.clone();
        }
    }
}

impl fmt::Display for SnmpStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            SnmpStatus::Unknown => "UNKNOWN",
        };
        write!(f, "{}", s)
    }
}

impl Serialize for SnmpStatus {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut s = serializer.serialize_struct("SnmpStatus", 2)?;
        match self {
            SnmpStatus::Unknown => {
                s.serialize_field("status", "unknown")?;
                s.serialize_field("msg", "")?;
            }
        }
        s.end()
    }
}

impl<'de> Deserialize<'de> for SnmpStatus {
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
            "unknown" => Ok(SnmpStatus::Unknown),
            other => Err(de::Error::unknown_variant(other, &["unknown"])),
        }
    }
}