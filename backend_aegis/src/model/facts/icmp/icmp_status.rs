use std::fmt;

use serde::{Serialize, Deserialize, Serializer, Deserializer};
use serde::ser::SerializeStruct;
use serde::de::{self};


/// ICMP status codes translated from Python Enum
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum IcmpStatus {
    Reachable,
    Unreachable(String),
    Timeout(String),
    HostNotFound(String),
    NameResolutionError(String),
    Unknown(String),
}

impl Default for IcmpStatus {
    fn default() -> Self {
        IcmpStatus::Unknown(String::new())
    }
}

impl IcmpStatus {
    /// Convert from integer code to enum
    pub fn from_i32(code: i32) -> Self {
        match code {
            0 => IcmpStatus::Reachable,
            1 => IcmpStatus::Unreachable(String::new()),
            2 => IcmpStatus::Timeout(String::new()),
            3 => IcmpStatus::HostNotFound(String::new()),
            4 => IcmpStatus::NameResolutionError(String::new()),
            _ => IcmpStatus::Unknown(String::new()),
        }
    }

    /// Convert enum back to integer code
    pub fn to_i32(&self) -> i32 {
        match self {
            IcmpStatus::Reachable => 0,
            IcmpStatus::Unreachable(_) => 1,
            IcmpStatus::Timeout(_) => 2,
            IcmpStatus::HostNotFound(_) => 3,
            IcmpStatus::NameResolutionError(_) => 4,
            IcmpStatus::Unknown(_) => -1,
        }
    }

    pub fn type_to_string(&self) -> &str{
        match self {
            IcmpStatus::Reachable => "Reachable",
            IcmpStatus::Unreachable(_) => "Unreachable",
            IcmpStatus::Timeout(_) => "Timeout",
            IcmpStatus::HostNotFound(_) => "HostNotFound",
            IcmpStatus::NameResolutionError(_) => "NameResolutionError",
            IcmpStatus::Unknown(_) => "Unknown",
        }
    }

    pub fn merge(&mut self, other: &IcmpStatus) {
        if matches!(self, IcmpStatus::Unknown(_)) {
            *self = other.clone();
        }
    }
}

/// Implement Display so it prints like the Python __str__ method
impl fmt::Display for IcmpStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            IcmpStatus::Reachable => "REACHABLE",
            IcmpStatus::Unreachable(_) => "UNREACHABLE",
            IcmpStatus::Timeout(_) => "TIMEOUT",
            IcmpStatus::HostNotFound(_) => "HOST_NOT_FOUND",
            IcmpStatus::NameResolutionError(_) => "NAME_RESOLUTION_ERROR",
            IcmpStatus::Unknown(_) => "UNKNOWN",
        };
        write!(f, "{}", s)
    }
}

impl Serialize for IcmpStatus {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut s = serializer.serialize_struct("IcmpStatus", 2)?;
        match self {
            IcmpStatus::Reachable => {
                s.serialize_field("status", "reachable")?;
                s.serialize_field("msg", "")?;
            }
            IcmpStatus::Unreachable(msg) => {
                s.serialize_field("status", "unreachable")?;
                s.serialize_field("msg", msg)?;
            }
            IcmpStatus::Timeout(msg) => {
                s.serialize_field("status", "timeout")?;
                s.serialize_field("msg", msg)?;
            }
            IcmpStatus::HostNotFound(msg) => {
                s.serialize_field("status", "hostnotfound")?;
                s.serialize_field("msg", msg)?;
            }
            IcmpStatus::NameResolutionError(msg) => {
                s.serialize_field("status", "nameresolutionerror")?;
                s.serialize_field("msg", msg)?;
            }
            IcmpStatus::Unknown(msg) => {
                s.serialize_field("status", "unknown")?;
                s.serialize_field("msg", msg)?;
            }
        }
        s.end()
    }
}

impl<'de> Deserialize<'de> for IcmpStatus {
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
            "reachable" => Ok(IcmpStatus::Reachable),
            "unreachable" => Ok(IcmpStatus::Unreachable(h.msg)),
            "timeout" => Ok(IcmpStatus::Timeout(h.msg)),
            "hostnotfound" => Ok(IcmpStatus::HostNotFound(h.msg)),
            "nameresolutionerror" => Ok(IcmpStatus::NameResolutionError(h.msg)),
            "unknown" => Ok(IcmpStatus::Unknown(h.msg)),
            other => Err(de::Error::unknown_variant(other, &[
                "reachable","unreachable","timeout","hostnotfound","nameresolutionerror","unknown"
            ])),
        }
    }
}
