use std::fmt;

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
