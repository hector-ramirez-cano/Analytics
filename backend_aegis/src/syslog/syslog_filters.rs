use chrono::{DateTime, FixedOffset, TimeZone, Utc};
use serde::Deserialize;
use std::collections::HashSet;

use crate::syslog::syslog_types::{SyslogFacility, SyslogSeverity};

#[derive(Debug, Deserialize)]
pub struct SyslogFilters {
    #[serde(deserialize_with = "ts_to_datetime_utc6")]
    pub start_time: DateTime<Utc>,

    #[serde(deserialize_with = "ts_to_datetime_utc6")]
    pub end_time: DateTime<Utc>,

    pub facilities: HashSet<SyslogFacility>,
    pub severities: HashSet<SyslogSeverity>,

    #[serde(default)]
    pub offset: i64,

    #[serde(default)]
    pub origin: String,

    #[serde(default)]
    pub pid: String,

    #[serde(default)]
    pub message: String,
}

fn ts_to_datetime_utc6<'de, D>(deserializer: D) -> Result<DateTime<Utc>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let ts = f64::deserialize(deserializer)?;
    let secs = ts as i64;
    let nanos = ((ts.fract()) * 1e9) as u32;

    let fixed_offset = FixedOffset::west_opt(6 * 3600)
        .ok_or_else(|| serde::de::Error::custom("invalid UTC-6 offset"))?;

    let local_dt = fixed_offset.timestamp_opt(secs, nanos)
        .single()
        .ok_or_else(|| serde::de::Error::custom("invalid timestamp"))?;

    Ok(local_dt.with_timezone(&Utc))
}