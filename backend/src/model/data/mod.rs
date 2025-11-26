use sqlx::Type;
use serde::{Serialize, Deserialize};

pub mod device;
pub mod group;
pub mod link;
pub mod analytics_item;
pub mod device_configuration;
pub mod device_state;
pub mod item_type;
pub mod link_type;
pub mod data_source;
pub mod dashboard;


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