use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Dashboard {
    #[serde(rename="id")]
    pub dashboard_id: i64,

    #[serde(rename="name")]
    pub dashboard_name: String,

    #[serde(rename="members")]
    pub members: Vec<DashboardItem>
}

impl Dashboard {
    pub fn new(dashboard_id: i64, dashboard_name: String, members: Vec<DashboardItem>) -> Self {
        Self { dashboard_id, dashboard_name, members }
    }
}


#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct DashboardItem {
    #[serde(rename="id")]
    pub dashboard_id: i64,
    
    #[serde(rename="row-start")]
    pub row_start   : i16,

    #[serde(rename="row-span")]
    pub row_span    : i16,

    #[serde(rename="col-start")]
    pub col_start   : i16,

    #[serde(rename="col-span")]
    pub col_span    : i16,

    #[serde(rename="style-definition")]
    pub style_definition: Value,

    #[serde(rename="polling-definition")]
    pub polling_definition: Value,
}
