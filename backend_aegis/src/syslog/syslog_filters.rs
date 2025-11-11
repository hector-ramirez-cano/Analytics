
use chrono::{DateTime, TimeZone, Utc};
use serde::Deserialize;

use crate::syslog::{SyslogFacility, SyslogFilters, SyslogSeverity};

pub fn ts_to_datetime_utc6<'de, D>(deserializer: D) -> Result<DateTime<Utc>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let ts = f64::deserialize(deserializer)?;
    let secs = ts as i64;
    let nanos = ((ts.fract()) * 1e9) as u32;

    let local_dt = Utc.timestamp_opt(secs, nanos)
        .single()
        .ok_or_else(|| serde::de::Error::custom("invalid timestamp"))?;

    Ok(local_dt.with_timezone(&Utc))
}

impl SyslogFilters {
    pub fn has_facility_filters(&self) -> bool {
        SyslogFacility::all().len() != self.facilities.len()
    }

    pub fn has_severity_filters(&self) -> bool {
        SyslogSeverity::all().len() != self.severities.len()
    }

    pub fn new_empty() -> Self {
        Self {
            start_time: DateTime::UNIX_EPOCH,
            end_time: DateTime::UNIX_EPOCH,
            facilities: SyslogFacility::all().iter().cloned().collect(),
            severities: SyslogSeverity::all().iter().cloned().collect(),
            offset: None,
            origin: None,
            pid: None,
            message: None,
            page_size: Some(30),
        }
    }
}