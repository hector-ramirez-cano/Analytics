use sqlx::FromRow;

pub mod dashboard_operations;
pub mod syslog_operations;
pub mod influx_operations;
pub mod alert_operations;
pub mod telegram_operations;
pub mod commit_changes;

#[derive(FromRow)]
struct RowCount {
    total : i64
}