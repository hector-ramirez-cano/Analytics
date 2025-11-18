
use sqlx::{Pool, Postgres, QueryBuilder};

use crate::{model::db::operations::RowCount, syslog::{SyslogFacility, SyslogFilters, SyslogMessage, SyslogSeverity}};


pub async fn update_database(postgres_pool: &Pool<Postgres>, msg: &SyslogMessage) -> Result<(), ()> {
    let time = msg.received_at.unwrap_or_default();
    let hostname = msg.source.clone().unwrap_or_default();
    let procid = msg.procid.clone().unwrap_or(String::new()).to_string();
    let result = sqlx::query!(r#"
        INSERT INTO Syslog.system_events
            (facility, severity, from_host, received_at, process_id, message, message_id, appname)
        VALUES($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
        msg.facility as SyslogFacility,
        msg.severity as SyslogSeverity,
        hostname,
        time,
        procid,
        msg.msg,
        msg.msgid,
        msg.appname
    ).execute(postgres_pool).await;

    if let Err(e) = result {
        log::error!("[ERROR][SYSLOG][DB] Failed to insert into database, sql error = '{e}'");
    }

    Ok(())
}

fn append_where_clause(filters: & SyslogFilters, query : & mut QueryBuilder<Postgres>, limit: Option<i64>, include_ordering_clause: bool) {
    let mut where_clause = query.separated(" AND ");

    where_clause.push(" WHERE received_at BETWEEN ")
        .push_bind_unseparated(filters.start_time)
        .push( "")
        .push_bind_unseparated(filters.end_time);

    if filters.has_facility_filters() {
        let fac : Vec<i16> = filters.facilities.iter().map(|f| *f as i16).collect();
        where_clause.push("facility = ANY(").push_bind_unseparated(fac).push_unseparated(")");
    }

    if filters.has_severity_filters() {
        let sev : Vec<i16> = filters.severities.iter().map(|s| *s as i16).collect();
        where_clause.push("severity = ANY(").push_bind_unseparated(sev).push_unseparated(")");
    }

    if let Some(pid) = &filters.pid && !pid.is_empty() {
        where_clause.push("process_id ILIKE ").push_bind_unseparated(pid.clone());
    }

    if let Some(origin) = &filters.origin && !origin.is_empty() {
        where_clause.push("from_host ILIKE ").push_bind_unseparated(origin.clone());
    }

    if !include_ordering_clause { return; }

    let mut ordering_clause = query.separated(" ");
    let mut needs_limit = filters.offset.is_some();
    if let Some(msg) = &filters.message && !msg.is_empty() {
        ordering_clause.push(" ORDER BY ts_rank_cd(message_tsv, websearch_to_tsquery('english', ")
            .push_bind_unseparated(msg.clone())
            .push("")
            .push_unseparated("))");

        // Override, in case there's no offset, we still need a limit
        needs_limit = true;
    }

    let offset = filters.offset.unwrap_or(0);
    let limit = limit.unwrap_or(-1);
    if needs_limit {
        ordering_clause.push("LIMIT").push_bind(limit).push("OFFSET").push_bind(offset);
    }
}


pub async fn get_row_count(filters: &SyslogFilters, postgres_pool: &Pool<Postgres>) -> i64 {
    let mut query = QueryBuilder::<Postgres>::new("SELECT COUNT(1) as total FROM Syslog.system_events");

    append_where_clause(&filters, &mut query, None, false);

    #[cfg(debug_assertions)] { log::info!("[DEBUG][DB][SYSLOG] query={}", query.sql()); }

    let query = query.build_query_as::<RowCount>();
    let result = query.fetch_one(postgres_pool).await;

    match result {
        Ok(v) => v.total,
        Err(e) => {
            log::error!("[ERROR][DB][SYSLOG] Failed to query for row count with error = '{e}'");
            0
        }
    }
}

pub async fn get_rows(row_count_fetch: i64, filters: &SyslogFilters, postgres_pool: &Pool<Postgres>) -> Vec<SyslogMessage> {
    let mut query = QueryBuilder::<Postgres>::new(concat! (
        "SELECT ",
            "id, facility, severity, from_host, received_at, process_id, message, ",
            "NULL::text as appname, NULL::text as msgid ",
        "FROM Syslog.system_events "
    ));

    append_where_clause(filters, &mut query, Some(row_count_fetch), true);
    #[cfg(debug_assertions)] { log::info!("[DEBUG][DB][SYSLOG] query={}", query.sql()); }

    let query = query.build_query_as::<SyslogMessage>();
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