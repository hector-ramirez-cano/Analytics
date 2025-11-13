use sqlx::Postgres;

use crate::{alerts::alert_backend::AlertBackend, model::db::fetch_topology::get_topology_as_json_str};

pub async fn api_get_topology(pool: &sqlx::Pool<Postgres>) -> Result<String, rocket::http::Status> {
    Ok(get_topology_as_json_str(pool).await?)
}

pub async fn api_get_rules() -> Result<serde_json::Value, rocket::http::Status> {
    Ok(AlertBackend::get_rules_as_json().await)
}