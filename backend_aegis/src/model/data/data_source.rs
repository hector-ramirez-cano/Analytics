use sqlx::Type;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize, Type, Eq, PartialEq, Hash, PartialOrd, Ord)]
#[sqlx(type_name = "DataSource", rename_all = "lowercase")]
pub enum DataSource {
    #[serde(rename="ssh")]
    Ssh,

    #[serde(rename="snmp")]
    Snmp,

    #[serde(rename="icmp")]
    Icmp,
}

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
