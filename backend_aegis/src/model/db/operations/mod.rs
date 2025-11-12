use sqlx::FromRow;

pub mod dashboard_operations;
pub mod syslog_operations;
pub mod influx_operations;
pub mod alert_operations;

#[derive(FromRow)]
struct RowCount {
    total : i64
}