use sqlx::Postgres;

use crate::{AegisError, alerts::alert_backend::AlertBackend, model::db::fetch_topology::get_topology_as_json};

pub async fn api_get_topology(pool: &sqlx::Pool<Postgres>) -> Result<serde_json::Value, AegisError> {
    get_topology_as_json(pool).await
}

pub async fn api_get_rules() -> Result<serde_json::Value, rocket::http::Status> {
    Ok(AlertBackend::get_rules_as_json().await)
}