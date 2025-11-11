use chrono::{DateTime, TimeZone, Utc};
use serde::Deserialize;
use std::collections::HashSet;

#[derive(Debug, Deserialize)]
pub struct AlertFilters {
    #[serde(deserialize_with = "ts_to_datetime")]
    pub start_time: DateTime<Utc>,

    #[serde(deserialize_with = "ts_to_datetime")]
    pub end_time: DateTime<Utc>,

    pub alert_id: i64,

    #[serde(default, deserialize_with = "opt_ts_to_datetime")]
    pub ack_start_time: Option<DateTime<Utc>>,

    #[serde(default, deserialize_with = "opt_ts_to_datetime")]
    pub ack_end_time: Option<DateTime<Utc>>,

    pub severities: HashSet<AlertSeverity>,

    #[serde(default)]
    pub message: String,

    #[serde(default)]
    pub ack_actor: Option<i64>,

    #[serde(default)]
    pub target_id: Option<i64>,

    #[serde(default)]
    pub offset: Option<i64>,

    #[serde(default)]
    pub requires_ack: Option<bool>,
}
