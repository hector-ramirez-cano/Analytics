use std::str::FromStr;

use crate::model::alerts::AlertReduceLogic;

impl AlertReduceLogic {
    /// Parse from string, returning None if invalid
    pub fn from_str_fallback(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "all" => Some(Self::All),
            "any" => Some(Self::Any),
            _ => None,
        }
    }
}

impl FromStr for AlertReduceLogic {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        AlertReduceLogic::from_str_fallback(s).ok_or(())
    }
}

impl std::fmt::Display for AlertReduceLogic {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            AlertReduceLogic::All => "ALL",
            AlertReduceLogic::Any => "ANY",
            AlertReduceLogic::Unknown => "UNKNOWN",
        };
        write!(f, "{}", s)
    }
}
