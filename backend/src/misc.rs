use std::collections::HashSet;

use chrono::{DateTime, TimeZone, Utc};
use serde::Deserialize;

pub fn ts_to_datetime_utc<'de, D>(deserializer: D) -> Result<DateTime<Utc>, D::Error>
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

pub fn opt_ts_to_datetime_utc<'de, D>(deserializer: D) -> Result<Option<DateTime<Utc>>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    Ok(Some(ts_to_datetime_utc(deserializer)?))
}

pub fn parse_json_array(field: Option<serde_json::Value>) -> HashSet<String> {
    match field {
        Some(serde_json::Value::Array(arr)) => arr
            .into_iter()
            .filter_map(|v| v.as_str().map(String::from))
            .collect(),
        _ => HashSet::new(),
    }
}

pub fn hashset_to_json_array(set: &HashSet<String>) -> serde_json::Value {
    let arr: Vec<serde_json::Value> = set.iter().map(|s| serde_json::Value::String(s.clone())).collect();
    serde_json::Value::Array(arr)
}