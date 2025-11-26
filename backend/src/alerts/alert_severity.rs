use std::str::FromStr;

use crate::alerts::AlertSeverity;

impl AlertSeverity {
    /// Returns severity level where 0 is most severe
    pub fn severity_level(&self) -> u8 {
        match self {
            AlertSeverity::Emergency => 0,
            AlertSeverity::Alert     => 1,
            AlertSeverity::Critical  => 2,
            AlertSeverity::Error     => 3,
            AlertSeverity::Warning   => 4,
            AlertSeverity::Notice    => 5,
            AlertSeverity::Info      => 6,
            AlertSeverity::Debug     => 7,
            AlertSeverity::Unknown   => 8,
        }
    }

    pub fn all() -> &'static [AlertSeverity] {
        use AlertSeverity::*;
        &[
            Emergency, Alert  , Critical,
            Error    , Warning, Notice  ,
            Info     , Debug  , Unknown ,
        ]
    }
}

impl std::fmt::Display for AlertSeverity {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            AlertSeverity::Emergency => "emergency",
            AlertSeverity::Alert     => "alert",
            AlertSeverity::Critical  => "critical",
            AlertSeverity::Error     => "error",
            AlertSeverity::Warning   => "warning",
            AlertSeverity::Notice    => "notice",
            AlertSeverity::Info      => "info",
            AlertSeverity::Debug     => "debug",
            AlertSeverity::Unknown   => "unknown",
        };
        write!(f, "{}", s)
    }
}

impl FromStr for AlertSeverity {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "emergency" => Ok(Self::Emergency),
            "alert"     => Ok(Self::Alert),
            "critical"  => Ok(Self::Critical),
            "error"     => Ok(Self::Error),
            "warning"   => Ok(Self::Warning),
            "notice"    => Ok(Self::Notice),
            "info"      => Ok(Self::Info),
            "debug"     => Ok(Self::Debug),
            _           => Err(()),
        }
    }
}
