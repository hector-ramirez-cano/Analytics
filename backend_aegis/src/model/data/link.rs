
use serde::{Deserialize, Serialize};

use crate::model::data::link_type::LinkType;

#[derive(Clone, Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Link {
    #[serde(rename = "id")]
    pub link_id: i64,

    #[serde(rename = "side-a")]
    pub side_a: i64,

    #[serde(rename = "side-b")]
    pub side_b: i64,

    #[serde(rename = "side-a-iface")]
    pub side_a_iface: String,

    #[serde(rename = "side-b-iface")]
    pub side_b_iface: String,

    #[serde(rename = "link-type")]
    pub link_type: LinkType,
    
    #[serde(rename = "link-subtype")]
    pub link_subtype: Option<String>,
}

impl Link {
    pub fn to_map(&self) -> serde_json::Value {
        serde_json::json!({
            "id": self.link_id,
            "side-a": self.side_a,
            "side-b": self.side_b,
            "link-type": self.link_type,
            "side-a-iface": self.side_a_iface,
            "side-b-iface": self.side_b_iface,
            // include subtype only if present
            "link-subtype": self.link_subtype,
        })
    }
}
