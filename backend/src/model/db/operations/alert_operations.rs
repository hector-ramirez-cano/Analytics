
use chrono::Utc;
use sqlx::{Pool, Postgres, QueryBuilder, Transaction};

use crate::{alerts::{AlertEvent, AlertFilters, AlertRule, AlertSeverity}, model::db::operations::RowCount, types::AlertEventId};

pub async fn ack_alert<'e>(alert_id : AlertEventId, ack_actor: &str, transaction: &mut Transaction<'e, Postgres>) -> Result<(), ()>{
    let mut ack_actor = ack_actor.to_string();
    ack_actor.truncate(253);

    let ack_time = Utc::now();

    let result = sqlx::query!("
        UPDATE Analytics.Alerts SET ack_actor = $1, ack_time = $2 WHERE alert_id = $3 AND ack_time IS NULL",
        ack_actor, ack_time, alert_id 
    ).execute(&mut **transaction).await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => {
            log::error!("[ERROR][ALERTS][DB] Failed to ack alert event with SQL Error = '{e}'");
            Err(())
        }
    }
}

pub async fn insert_alert(alert: &AlertEvent, pool : &sqlx::Pool<sqlx::Postgres>) -> Result<AlertEventId, sqlx::Error> {
    let alert_time = alert.alert_time.unwrap_or_default();
    let severity: AlertSeverity = alert.severity;

    let result = sqlx::query!(r#"
        INSERT INTO Analytics.alerts(alert_time, requires_ack, severity, message, target_id, rule_id, value)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING alert_id;
        "#,
        alert_time, alert.requires_ack, severity as AlertSeverity, alert.message, alert.target_id, alert.rule_id, alert.value
    ).fetch_one(pool).await;

    match result {
        Ok(r) => { 
            let id = r.alert_id;
            Ok(id)
        }
        Err(e) => {
            log::error!("[ERROR][ALERTS][DB] Failed to insert alert into database. SQL Error = '{e}'");
            Err(e)
        },
    }
}

fn append_where_clause(filters: &AlertFilters, query: &mut QueryBuilder<Postgres>, limit: Option<i64>) {
    let mut where_clause = query.separated(" AND ");

    where_clause.push( " WHERE alert_time BETWEEN ")
        .push_bind_unseparated(filters.start_time)
        .push("")
        .push_bind_unseparated(filters.end_time)
        .push_unseparated(" ");

    if filters.has_severity_filters() {
        let sev: Vec<i16> = filters.severities.iter().map(|s| *s as i16).collect();
        where_clause.push(" severity = ANY( ").push_bind_unseparated(sev).push_unseparated(" ) ");
    }

    if let Some(ack_start) = filters.ack_start_time && let Some(ack_end) = filters.ack_end_time {
        where_clause.push(" ack_time BETWEEN ")
            .push_bind_unseparated(ack_start)
            .push("")
            .push_bind_unseparated(ack_end)
            .push_unseparated(" ) ");
    }

    if let Some(alert_id) = filters.alert_id {
        where_clause.push(" alert_id = ").push_bind_unseparated(alert_id);
    }

    if let Some(message) = &filters.message {
        where_clause.push(" message LIKE ").push_bind_unseparated(message.clone());
    }

    if let Some(ack_actor) = filters.ack_actor {
        where_clause.push(" ack_actor LIKE ").push_bind_unseparated(ack_actor);
    }

    if let Some(target_id) = filters.target_id {
        where_clause.push(" target_id = ").push_bind_unseparated(target_id);
    }

    if let Some(requires_ack) = filters.requires_ack {
        where_clause.push(" requires_ack = ").push_bind_unseparated(requires_ack);
    }

    let mut ordering_clause = query.separated(" ");
    let offset = filters.offset.unwrap_or(0);
    if let Some(limit) = limit {
        ordering_clause.push(" LIMIT ").push_bind(limit).push(" OFFSET ").push_bind(offset);
    }
}

pub async fn get_row_count(filters: &AlertFilters, postgres_pool: &Pool<Postgres>) -> i64 {
    let mut query = QueryBuilder::<Postgres>::new("SELECT COUNT(1) as total FROM Analytics.alerts ");

    append_where_clause(&filters, &mut query, None);

    #[cfg(debug_assertions)] { log::info!("[DEBUG][DB][ALERTS] query={}", query.sql()); }

    let query = query.build_query_as::<RowCount>();
    let result = query.fetch_one(postgres_pool).await;

    match result {
        Ok(v) => v.total,
        Err(e) => {
            log::error!("[ERROR][DB][ALERTS] Failed to query for row count with error = '{e}'");
            0
        }
    }
}

pub async fn get_rows(row_count_fetch: i64, filters: &AlertFilters, postgres_pool: &Pool<Postgres>) -> Vec<AlertEvent> {
    let mut query = QueryBuilder::<Postgres>::new(concat! (
        "SELECT ",
            "alert_id, alert_time, ack_time, requires_ack, severity, message, target_id, ",
            "TRUE as ws_notified, TRUE as db_notified, (ack_actor IS NOT NULL) as acked, ack_actor, rule_id, value ",
        "FROM Analytics.alerts "
    ));

    append_where_clause(filters, &mut query, Some(row_count_fetch));

    #[cfg(debug_assertions)] { log::info!("[DEBUG][DB][ALERTS] query={}", query.sql()); }

    let query = query.build_query_as::<AlertEvent>();
    let result = query.fetch_all(postgres_pool).await;

    match result {
        Ok(r) => r,
        Err(e) => {
            // Don't propagate the error outwards. Print it, and allow to recover
            log::error!("[ERROR][DB][SYSLOG] Failed to query database with error = '{e}'");
            Vec::new()
        }
    }

}

pub async fn get_alert_rules(postgres_pool: &Pool<Postgres>) -> Result<Vec<AlertRule>, ()> {
    let rules = sqlx::query!("SELECT * FROM Analytics.alert_rules;").fetch_all(postgres_pool).await;
    let rules = match rules { Ok(r) => r, Err(e) => {
        log::error!("[ERROR][ALERTS][LOADS] Failed to load rules from database with error = '{e}'");
        println!("[ERROR][ALERTS][LOADS] Failed to load rules from database with error = '{e}'");
        return Err(());
    }};

    let mut result = Vec::with_capacity(rules.len());
    for record in rules {
        let mut rule: AlertRule = match serde_json::from_value(record.rule_definition) {
            Ok(r) => r,
            Err(e) => {
                log::warn!("[WARN ][ALERTS][LOADS] Failed to load rule {}-'{}' from database- Definition is invalid. Error = '{e}'. Ignoring...", record.rule_id, record.rule_name);
                println!("[WARN ][ALERTS][LOADS] Failed to load rule {}-'{}' from database- Definition is invalid. Error = '{e}'. Ignoring...", record.rule_id, record.rule_name);
                continue;
            }
        };

        // Database is king and ruler above all!
        // don't trust Ye mighty json contents!
        // Overwrite with actual database rows for:
        rule.rule_id      = record.rule_id;
        rule.name         = record.rule_name.clone();
        rule.requires_ack = record.requires_ack;

        result.push(rule);
    }

    Ok(result)
}