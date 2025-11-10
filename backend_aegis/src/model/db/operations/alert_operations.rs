use sqlx::types::chrono::DateTime;

use crate::model::alerts::AlertEvent;



pub async fn insert_alert(alert: &AlertEvent, pool : &sqlx::Pool<sqlx::Postgres>) -> Result<i64, sqlx::Error> {
    let sev: i16 = alert.severity.severity_level().into();
    let alert_time = alert.alert_time.unwrap_or(DateTime::default()).naive_utc();

    let result = sqlx::query!(r#"
        INSERT INTO Analytics.alerts(alert_time, requires_ack, severity, message, target_id, value)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING alert_id;
        "#,
        alert_time, alert.requires_ack, sev as i16, alert.message, alert.target_id, alert.value
    ).fetch_one(pool).await;

    let id = result?.alert_id;

    Ok(id)
}