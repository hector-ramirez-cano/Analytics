use crate::model::db::fetch_topology::{get_topology_as_json_str};

pub async fn api_get_topology(pool: &rocket::State<sqlx::PgPool>) -> Result<String, rocket::http::Status> {
    Ok(get_topology_as_json_str(pool).await?)
}