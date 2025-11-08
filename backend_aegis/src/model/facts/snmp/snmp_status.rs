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
