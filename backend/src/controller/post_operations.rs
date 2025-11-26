use sqlx::Postgres;

use crate::model::db::operations::commit_changes::commit;


pub async fn api_configure(data: serde_json::Value, pool: &sqlx::Pool<Postgres>) -> Result<(), (String, i16)> {
    commit(data, pool).await
}