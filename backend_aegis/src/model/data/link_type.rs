use sqlx::Type;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize, Type)]
#[sqlx(type_name = "linktype", rename_all = "lowercase")]
pub enum LinkType {
    #[serde(rename="optical")]
    Optical,

    #[serde(rename="copper")]
    Copper,

    #[serde(rename="wireless")]
    Wireless,

    #[serde(rename="unknown")]
    Unknown,
}

impl From<Option<LinkType>> for LinkType {
    fn from(value: Option<LinkType>) -> Self {
        value.unwrap_or(LinkType::Unknown)
    }
}