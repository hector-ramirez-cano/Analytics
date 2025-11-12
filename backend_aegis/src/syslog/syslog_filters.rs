
use chrono::DateTime;

use crate::syslog::{SyslogFacility, SyslogFilters, SyslogSeverity};

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