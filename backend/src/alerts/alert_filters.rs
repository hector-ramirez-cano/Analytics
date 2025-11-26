
use crate::alerts::{AlertFilters, AlertSeverity};

impl AlertFilters {
    pub fn has_severity_filters(&self) -> bool {
        AlertSeverity::all().len() != self.severities.len()
    }
}