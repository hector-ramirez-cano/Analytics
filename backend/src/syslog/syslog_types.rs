use std::fmt;
use std::convert::TryFrom;
use sqlx::types::chrono::{DateTime, Utc};

use crate::syslog::{SyslogFacility, SyslogMessage, SyslogSeverity};


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

impl SyslogSeverity {
    pub fn all() -> &'static [SyslogSeverity] {
        use SyslogSeverity::*;

        &[
            Emerg, Alert  , Crit  ,
            Err  , Warning, Notice,
            Info , Debug  ,
        ]
    }
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
            syslog_loose::SyslogFacility::LOG_AUDIT    => SyslogFacility::Security,
            syslog_loose::SyslogFacility::LOG_ALERT    => SyslogFacility::Console,
            syslog_loose::SyslogFacility::LOG_CLOCKD   => SyslogFacility::Solaris,
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
            13 => Ok(SyslogFacility::Security),
            14 => Ok(SyslogFacility::Console),
            15 => Ok(SyslogFacility::Solaris),
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
            SyslogFacility::Security => "security",
            SyslogFacility::Console => "console",
            SyslogFacility::Solaris => "solaris",
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

impl SyslogFacility {
    pub fn all() -> &'static [SyslogFacility] {
        use SyslogFacility::*;
        &[
            Kern  , User  , Mail    , Daemon,
            Auth  , Syslog, Lpr     , News  ,
            Uucp  , Cron  , AuthPriv, Ftp   ,
            Ntp   , Security , Console   , Solaris,
            Local0, Local1, Local2  , Local3,
            Local4, Local5, Local6  , Local7,
        ]
    }
}

impl<'a> From<syslog_loose::Message<&'a str>> for SyslogMessage {
    fn from(m: syslog_loose::Message<&'a str>) -> Self {
        let hostname = m.hostname.map(|h| h.to_string());
        let appname  = m.appname.map(|h| h.to_string());
        let procid   = m.procid.map(|h| h.to_string());
        let msgid    = m.msgid.map(|h| h.to_string());
        let facility = if let Some(f) = m.facility { f.into() } else { SyslogFacility::Local7 };
        let severity = if let Some(s) = m.severity { s.into() } else { SyslogSeverity::Err };

        let msg = m.msg.to_string();

        SyslogMessage {
            id: -1,
            facility,
            severity,
            source: hostname,
            procid,
            received_at: m.timestamp.map(|ts|  DateTime::<Utc>::from_naive_utc_and_offset(ts.naive_local(), Utc)),
            msg,
            appname,
            msgid,
        }
    }
}