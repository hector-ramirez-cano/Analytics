

use crate::model::data::DataSource;

impl From<Option<DataSource>> for DataSource {
    fn from(value: Option<DataSource>) -> Self {
        value.unwrap_or(DataSource::Ssh)
    }
}

impl From<Option<&str>> for DataSource {
    fn from(value: Option<&str>) -> Self {
        match value {
            Some("ssh") => DataSource::Ssh,
            Some("snmp") => DataSource::Snmp,
            Some("icmp") => DataSource::Ssh,
            _ => DataSource::Ssh
        }
    }
}
