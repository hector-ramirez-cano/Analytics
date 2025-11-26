use std::collections::HashMap;

use crate::{AegisError, model::data::dashboard::Dashboard, types::DashboardId};

#[allow(unused)] // Needs to be allowed. Needed for compilation, but the compiler complains of a type casting needed if it's removed
use crate::model::data::dashboard::DashboardItem;

pub async fn get_dashboards_as_json(pool: &sqlx::PgPool) -> Result<HashMap<DashboardId, Dashboard>, AegisError>{
    let dashboard_members = sqlx::query_as!(DashboardItem, "SELECT dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition FROM Analytics.dashboard_items")
    .fetch_all(&*pool)
    .await
    .map_err(|e| AegisError::Sql(e))?;

    let mut items = HashMap::new();
    for member in dashboard_members {
        if !items.contains_key(&member.dashboard_id) {
            items.insert(member.dashboard_id, vec![member]);
        } else {
            let members = items.get_mut(&member.dashboard_id).expect("Unreachable code");
            members.push(member);
        };
    }
    
    let rows = sqlx::query!(r#"
        SELECT dashboard_id, dashboard_name FROM Analytics.dashboard;"#
    )
    .fetch_all(&*pool)
    .await
    .map_err(|e| AegisError::Sql(e))?;

    let mut dashboards = HashMap::new();
    for row in rows {
        let dashboard_id = row.dashboard_id;
        let dashboard_name = row.dashboard_name;
        let members = items.remove(&dashboard_id).unwrap_or(Vec::new());
        let dashboard = Dashboard::new(dashboard_id, dashboard_name, members);

        dashboards.insert(dashboard_id, dashboard);
    }

    return Ok(dashboards);
}

