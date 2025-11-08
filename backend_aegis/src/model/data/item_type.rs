use sqlx::Type;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize, Type)]
#[sqlx(type_name = "itemtype", rename_all = "lowercase")]
pub enum ItemType {
    Device,
    Link,
    Group,
}