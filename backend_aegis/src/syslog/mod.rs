use std::collections::HashSet;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use sqlx::Type;

use crate::misc::ts_to_datetime_utc;

pub mod syslog_backend;
pub mod syslog_types;
pub mod syslog_filters;

// TODO: Serde
#[derive(Debug, Clone, FromRow, Serialize, Deserialize)]
pub struct SyslogMessage {
    pub id: i64,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub facility: Option<SyslogFacility>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub severity: Option<SyslogSeverity>,

    #[serde(skip_serializing_if = "Option::is_none")]
    #[sqlx(rename="from_host")]
    pub source: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub received_at: Option<DateTime<Utc>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    #[sqlx(rename="appname")]
    pub appname: Option<String>, // Keeping only as reference in the db. Not exposed via websocket

    #[serde(skip_serializing_if = "Option::is_none")]
    #[sqlx(rename="process_id")]
    pub procid: Option<String>, // TODO: Might be able to be removed from here and from frontend

    #[serde(skip_serializing_if = "Option::is_none")]
    pub msgid: Option<String>, // Keeping only as reference in the db. Not exposed via websocket

    #[sqlx(rename="message")]
    pub msg: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type, Hash)]
#[repr(i16)]
#[serde(rename_all="lowercase")]
pub enum SyslogSeverity {
    Emerg = 0,
    Alert = 1,
    Crit = 2,
    Err = 3,
    Warning = 4,
    Notice = 5,
    Info = 6,
    Debug = 7,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type, Hash)]
#[repr(i16)]
#[serde(rename_all="lowercase")]
pub enum SyslogFacility {
    Kern = 0,
    User = 1,
    Mail = 2,
    Daemon = 3,
    Auth = 4,
    Syslog = 5,
    Lpr = 6,
    News = 7,
    Uucp = 8,
    Cron = 9,
    AuthPriv = 10,
    Ftp = 11,
    Ntp = 12,
    Audit = 13,
    Alert = 14,
    Clockd = 15,
    Local0 = 16,
    Local1 = 17,
    Local2 = 18,
    Local3 = 19,
    Local4 = 20,
    Local5 = 21,
    Local6 = 22,
    Local7 = 23,
}


#[derive(Debug, Deserialize, Serialize)]
pub struct SyslogFilters {
    #[serde(deserialize_with = "ts_to_datetime_utc", rename="start")]
    pub start_time: DateTime<Utc>,

    #[serde(deserialize_with = "ts_to_datetime_utc", rename="end")]
    pub end_time: DateTime<Utc>,

    #[serde(rename="facility")]
    pub facilities: HashSet<SyslogFacility>,
    
    #[serde(rename="severity")]
    pub severities: HashSet<SyslogSeverity>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub offset: Option<i64>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub origin: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pid: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,

    #[serde(rename = "page-size", skip_serializing_if = "Option::is_none")]
    pub page_size: Option<i64>,
}