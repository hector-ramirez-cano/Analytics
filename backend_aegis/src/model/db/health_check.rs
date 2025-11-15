use sqlx::Postgres;


pub async fn check_connections(pool: &sqlx::Pool<Postgres>, influx_client: &influxdb2::Client) -> serde_json::Value {
    
    // Postgres
    let postgres_status = 
    match sqlx::query("SELECT 1").fetch_one(pool).await {
        Ok(_) => {
            serde_json::json!({"up": true, "msg": ""})
        },
        Err(e) => {
            serde_json::json!({"up": false, "msg": e.to_string()})
        }
    };

    let influx_status =
    match influx_client.health().await {
        Ok(health_check) => {
            let msg = health_check.message.unwrap_or_default();
            serde_json::json!({"up": health_check.status == influxdb2::models::Status::Pass, "msg": msg})
        },
        Err(e) => {
            serde_json::json!({"up": false, "msg": e.to_string()})
        }
    };
    
    serde_json::json!({
        "status": { "postgres": postgres_status, "influx": influx_status }
    })
}