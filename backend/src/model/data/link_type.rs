use sqlx::Type;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize, Type)]
#[sqlx(type_name = "link_type", rename_all = "lowercase")]
#[serde(rename_all="lowercase")]
pub enum LinkType {
    Optical,
    Copper,
    Wireless,
    Unknown,
}

impl From<Option<LinkType>> for LinkType {
    fn from(value: Option<LinkType>) -> Self {
        value.unwrap_or(LinkType::Unknown)
    }
}