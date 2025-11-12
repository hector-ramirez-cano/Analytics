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