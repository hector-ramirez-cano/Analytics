use std::fmt;

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
