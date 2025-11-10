use chrono::FixedOffset;
use sqlx::prelude::FromRow;
use syslog_loose::ProcId;
use std::fmt;
use std::convert::TryFrom;
use serde::{Serialize, Deserialize};
use sqlx::Type;
use sqlx::types::chrono::{DateTime, Utc};


//   ______                                           __    __               
//  /      \                                         /  |  /  |              
// /$$$$$$  |  ______   __     __  ______    ______  $$/  _$$ |_    __    __ 
// $$ \__$$/  /      \ /  \   /  |/      \  /      \ /  |/ $$   |  /  |  /  |
// $$      \ /$$$$$$  |$$  \ /$$//$$$$$$  |/$$$$$$  |$$ |$$$$$$/   $$ |  $$ |
//  $$$$$$  |$$    $$ | $$  /$$/ $$    $$ |$$ |  $$/ $$ |  $$ | __ $$ |  $$ |
// /  \__$$ |$$$$$$$$/   $$ $$/  $$$$$$$$/ $$ |      $$ |  $$ |/  |$$ \__$$ |
// $$    $$/ $$       |   $$$/   $$       |$$ |      $$ |  $$  $$/ $$    $$ |
//  $$$$$$/   $$$$$$$/     $/     $$$$$$$/ $$/       $$/    $$$$/   $$$$$$$ |
//                                                                 /  \__$$ |
//                                                                 $$    $$/ 
//                                                                  $$$$$$/  
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type, Hash)]
#[repr(i16)]
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

impl From<syslog_loose::SyslogSeverity> for SyslogSeverity {
    fn from(value: syslog_loose::SyslogSeverity) -> Self {
        match value {
            syslog_loose::SyslogSeverity::SEV_EMERG   => SyslogSeverity::Emerg,
            syslog_loose::SyslogSeverity::SEV_ALERT   => SyslogSeverity::Alert,
            syslog_loose::SyslogSeverity::SEV_CRIT    => SyslogSeverity::Crit,
            syslog_loose::SyslogSeverity::SEV_ERR     => SyslogSeverity::Err,
            syslog_loose::SyslogSeverity::SEV_WARNING => SyslogSeverity::Warning,
            syslog_loose::SyslogSeverity::SEV_NOTICE  => SyslogSeverity::Notice,
            syslog_loose::SyslogSeverity::SEV_INFO    => SyslogSeverity::Info,
            syslog_loose::SyslogSeverity::SEV_DEBUG   => SyslogSeverity::Debug,
        }
    }
}

impl TryFrom<i16> for SyslogSeverity {
    type Error = ();

    fn try_from(value: i16) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(SyslogSeverity::Emerg),
            1 => Ok(SyslogSeverity::Alert),
            2 => Ok(SyslogSeverity::Crit),
            3 => Ok(SyslogSeverity::Err),
            4 => Ok(SyslogSeverity::Warning),
            5 => Ok(SyslogSeverity::Notice),
            6 => Ok(SyslogSeverity::Info),
            7 => Ok(SyslogSeverity::Debug),
            _ => Err(()),
        }
    }
}

impl fmt::Display for SyslogSeverity {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            SyslogSeverity::Emerg => "emerg",
            SyslogSeverity::Alert => "alert",
            SyslogSeverity::Crit => "crit",
            SyslogSeverity::Err => "err",
            SyslogSeverity::Warning => "warning",
            SyslogSeverity::Notice => "notice",
            SyslogSeverity::Info => "info",
            SyslogSeverity::Debug => "debug",
        };
        write!(f, "{}", name)
    }
}



//  ________                   __  __  __    __               
// /        |                 /  |/  |/  |  /  |              
// $$$$$$$$/______    _______ $$/ $$ |$$/  _$$ |_    __    __ 
// $$ |__  /      \  /       |/  |$$ |/  |/ $$   |  /  |  /  |
// $$    | $$$$$$  |/$$$$$$$/ $$ |$$ |$$ |$$$$$$/   $$ |  $$ |
// $$$$$/  /    $$ |$$ |      $$ |$$ |$$ |  $$ | __ $$ |  $$ |
// $$ |   /$$$$$$$ |$$ \_____ $$ |$$ |$$ |  $$ |/  |$$ \__$$ |
// $$ |   $$    $$ |$$       |$$ |$$ |$$ |  $$  $$/ $$    $$ |
// $$/     $$$$$$$/  $$$$$$$/ $$/ $$/ $$/    $$$$/   $$$$$$$ |
//                                                  /  \__$$ |
//                                                  $$    $$/ 
//                                                   $$$$$$/  
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type, Hash)]
#[repr(i16)]
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

impl From<syslog_loose::SyslogFacility> for SyslogFacility {
    fn from(value: syslog_loose::SyslogFacility) -> Self {
        match value {
            syslog_loose::SyslogFacility::LOG_KERN     => SyslogFacility::Kern,
            syslog_loose::SyslogFacility::LOG_USER     => SyslogFacility::User,
            syslog_loose::SyslogFacility::LOG_MAIL     => SyslogFacility::Mail,
            syslog_loose::SyslogFacility::LOG_DAEMON   => SyslogFacility::Daemon,
            syslog_loose::SyslogFacility::LOG_AUTH     => SyslogFacility::Auth,
            syslog_loose::SyslogFacility::LOG_SYSLOG   => SyslogFacility::Syslog,
            syslog_loose::SyslogFacility::LOG_LPR      => SyslogFacility::Lpr,
            syslog_loose::SyslogFacility::LOG_NEWS     => SyslogFacility::News,
            syslog_loose::SyslogFacility::LOG_UUCP     => SyslogFacility::Uucp,
            syslog_loose::SyslogFacility::LOG_CRON     => SyslogFacility::Cron,
            syslog_loose::SyslogFacility::LOG_AUTHPRIV => SyslogFacility::AuthPriv,
            syslog_loose::SyslogFacility::LOG_FTP      => SyslogFacility::Ftp,
            syslog_loose::SyslogFacility::LOG_NTP      => SyslogFacility::Ntp,
            syslog_loose::SyslogFacility::LOG_AUDIT    => SyslogFacility::Audit,
            syslog_loose::SyslogFacility::LOG_ALERT    => SyslogFacility::Alert,
            syslog_loose::SyslogFacility::LOG_CLOCKD   => SyslogFacility::Clockd,
            syslog_loose::SyslogFacility::LOG_LOCAL0   => SyslogFacility::Local0,
            syslog_loose::SyslogFacility::LOG_LOCAL1   => SyslogFacility::Local1,
            syslog_loose::SyslogFacility::LOG_LOCAL2   => SyslogFacility::Local2,
            syslog_loose::SyslogFacility::LOG_LOCAL3   => SyslogFacility::Local3,
            syslog_loose::SyslogFacility::LOG_LOCAL4   => SyslogFacility::Local4,
            syslog_loose::SyslogFacility::LOG_LOCAL5   => SyslogFacility::Local5,
            syslog_loose::SyslogFacility::LOG_LOCAL6   => SyslogFacility::Local6,
            syslog_loose::SyslogFacility::LOG_LOCAL7   => SyslogFacility::Local7,
        }
    }
}

impl TryFrom<i16> for SyslogFacility {
    type Error = ();

    fn try_from(code: i16) -> Result<Self, Self::Error> {
        match code {
            0 => Ok(SyslogFacility::Kern),
            1 => Ok(SyslogFacility::User),
            2 => Ok(SyslogFacility::Mail),
            3 => Ok(SyslogFacility::Daemon),
            4 => Ok(SyslogFacility::Auth),
            5 => Ok(SyslogFacility::Syslog),
            6 => Ok(SyslogFacility::Lpr),
            7 => Ok(SyslogFacility::News),
            8 => Ok(SyslogFacility::Uucp),
            9 => Ok(SyslogFacility::Cron),
            10 => Ok(SyslogFacility::AuthPriv),
            11 => Ok(SyslogFacility::Ftp),
            12 => Ok(SyslogFacility::Ntp),
            13 => Ok(SyslogFacility::Audit),
            14 => Ok(SyslogFacility::Alert),
            15 => Ok(SyslogFacility::Clockd),
            16 => Ok(SyslogFacility::Local0),
            17 => Ok(SyslogFacility::Local1),
            18 => Ok(SyslogFacility::Local2),
            19 => Ok(SyslogFacility::Local3),
            20 => Ok(SyslogFacility::Local4),
            21 => Ok(SyslogFacility::Local5),
            22 => Ok(SyslogFacility::Local6),
            23 => Ok(SyslogFacility::Local7),
            _ => Err(()),
        }
    }
}

impl fmt::Display for SyslogFacility {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            SyslogFacility::Kern => "kern",
            SyslogFacility::User => "user",
            SyslogFacility::Mail => "mail",
            SyslogFacility::Daemon => "daemon",
            SyslogFacility::Auth => "auth",
            SyslogFacility::Syslog => "syslog",
            SyslogFacility::Lpr => "lpr",
            SyslogFacility::News => "news",
            SyslogFacility::Uucp => "uucp",
            SyslogFacility::Cron => "cron",
            SyslogFacility::AuthPriv => "authpriv",
            SyslogFacility::Ftp => "ftp",
            SyslogFacility::Ntp => "ntp",
            SyslogFacility::Audit => "security",
            SyslogFacility::Alert => "console",
            SyslogFacility::Clockd => "solaris",
            SyslogFacility::Local0 => "local0",
            SyslogFacility::Local1 => "local1",
            SyslogFacility::Local2 => "local2",
            SyslogFacility::Local3 => "local3",
            SyslogFacility::Local4 => "local4",
            SyslogFacility::Local5 => "local5",
            SyslogFacility::Local6 => "local6",
            SyslogFacility::Local7 => "local7",
        };
        write!(f, "{}", name)
    }
}



// TODO: Serde
#[derive(Debug, Clone, FromRow)]
pub struct SyslogMessage {
    pub facility: Option<SyslogFacility>,
    pub severity: Option<SyslogSeverity>,
    pub hostname: Option<String>,
    pub appname: Option<String>,
    pub procid: Option<ProcId<String>>,
    pub msgid: Option<String>,
    pub timestamp: Option<DateTime<Utc>>,
    pub msg: String,
}

impl<'a> From<syslog_loose::Message<&'a str>> for SyslogMessage {
    fn from(m: syslog_loose::Message<&'a str>) -> Self {
        let hostname = if let Some(h) = m.hostname { Some(h.to_string()) } else { None };
        let appname  = if let Some(h) = m.appname { Some(h.to_string()) } else { None };
        let procid   = if let Some(h) = m.procid { Some(ProcId::Name(h.to_string())) } else { None };
        let msgid    = if let Some(h) = m.msgid { Some(h.to_string()) } else { None };
        let facility = if let Some(f) = m.facility { Some(f.into()) } else { None };
        let severity = if let Some(s) = m.severity { Some(s.into()) } else { None };

        let msg = m.msg.to_string();

        SyslogMessage {
            facility: facility,
            severity: severity,
            hostname: hostname,
            appname: appname,
            procid: procid,
            msgid: msgid,
            timestamp: m.timestamp.map(|ts| DateTime::<Utc>::from(ts)),
            msg: msg,
        }
    }
}