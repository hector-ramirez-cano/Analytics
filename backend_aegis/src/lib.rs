use std::fmt;

pub mod controller;
pub mod model;
pub mod syslog;
pub mod alerts;
pub mod misc;

pub mod config;


#[derive(Debug)]
pub enum AegisError {
    Sql (sqlx::Error),
    Serde (serde_json::Error),
}

impl fmt::Display for AegisError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AegisError::Sql(e) => write!(f, "SQL error: {}", e),
            AegisError::Serde(e) => write!(f, "Serde error: {}", e),
        }
    }
}
