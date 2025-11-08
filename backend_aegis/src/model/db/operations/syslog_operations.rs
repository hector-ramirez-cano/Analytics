
use sqlx::{Pool, Postgres};

use crate::syslog::syslog_types::SyslogMessage;

// TODO: Check this mfer works
pub async fn update_database(postgres_pool: &Pool<Postgres>, msg: &SyslogMessage) -> Result<(), ()> {
    log::info!("[INFO ][SYSLOG] Updating Postgres with syslog message!");

    let time = msg.timestamp.unwrap_or_default();
    let hostname = msg.hostname.clone().unwrap_or_default();
    let procid = msg.procid.clone().unwrap_or(syslog_loose::ProcId::Name(String::new())).to_string();

    let _result = sqlx::query!(r#"
        INSERT INTO Syslog.system_events 
            (facility, priority, from_host, info_unit_id, received_at, syslog_tag, process_id, message)
        VALUES($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
        msg.facility.map(|f| f as i16),
        msg.severity.map(|s| s as i16),
        hostname,
        0,
        time,
        "UNKNOWN",
        procid,
        msg.msg,
    ).execute(postgres_pool).await;

    Ok(())
}