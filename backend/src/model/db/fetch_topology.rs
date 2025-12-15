use std::collections::{HashMap, HashSet};

use rocket::futures::TryFutureExt;
use sqlx::Postgres;
use sqlx::pool::PoolConnection;

use crate::AegisError;
use crate::misc::parse_json_array;
use crate::model::cache::Cache;
use crate::model::data::device::Device;
use crate::model::data::device_state::DeviceStatus;
use crate::model::data::link::Link;
use crate::model::data::group::Group;
use crate::model::data::device_configuration::DeviceConfiguration;
use crate::model::data::DataSource;
use crate::model::db::update_topology::update_topology_cache;
use crate::types::{DeviceId, GroupId, LinkId};

#[allow(unused)] // Needs to be allowed. Needed for compilation, but the compiler complains of a type casting needed if it's removed
use crate::model::data::link_type::LinkType;

#[derive(sqlx::FromRow)]
struct DeviceDataSource {
    device_id: DeviceId,
    fact_data_source: DataSource,
}


impl From<Option<DeviceDataSource>> for DeviceDataSource {
    fn from(value: Option<DeviceDataSource>) -> Self {
        value.unwrap_or(DeviceDataSource { device_id: 0, fact_data_source: DataSource::Icmp })
    }
}

pub async fn get_topology_as_json(pool: &sqlx::PgPool) -> Result<serde_json::Value, AegisError> {
    let mut conn = pool.acquire().await.map_err(AegisError::Sql)?;

    // Update before returning, if needed
    update_topology_cache(&mut conn, false).await?;

    // returning from Cache, Cache handles it
    Cache::instance().as_json().await
}

pub async fn get_topology_view_as_json(pool: &sqlx::Pool<Postgres>) -> Result<serde_json::Value, AegisError> {
    // Return from sql, directly into JSON because there's not need to keep a local cache or create a struct
    let rows: Vec<serde_json::Value> = sqlx::query_scalar(
        r#"
        SELECT json_build_object(
            'id', v.topology_views_id,
            'name', v.name,
            'members', COALESCE(
                json_agg(
                    json_build_object(
                        'id', m.item_id,
                        'x', m.position_x::DOUBLE PRECISION,
                        'y', m.position_y::DOUBLE PRECISION
                    )
                ) FILTER (WHERE m.item_id IS NOT NULL),
                '[]'
            )
        )
        FROM Analytics.topology_views v
        LEFT JOIN Analytics.topology_views_member m
            ON v.topology_views_id = m.topology_views_id
        GROUP BY v.topology_views_id, v.name;
        "#
    )
    .fetch_all(pool)
    .await
    .map_err(AegisError::Sql)?;

    Ok(serde_json::Value::Array(rows))
}



pub async fn query_devices(conn: &mut PoolConnection<Postgres>) -> Result<HashMap<DeviceId, Device>, AegisError>{
    // Query datasources
    let mut datasources : HashMap<DeviceId, HashSet<DataSource>> = HashMap::new();
    let rows = sqlx::query_as!(
        DeviceDataSource, 
        r#"
            SELECT device_id,
                fact_data_source::TEXT as "fact_data_source: DataSource"
            FROM Analytics.device_data_sources
            "#
    )
        .fetch_all(&mut **conn)
        .await
        .map_err(AegisError::Sql)?;

    for row in rows {
        let device_id = row.device_id;

        datasources.entry(device_id)
            .or_default()
            .insert(row.fact_data_source);
    }
    
    // Query devices themselves
    let rows = sqlx::query!(
        "SELECT Analytics.devices.device_id, device_name, latitude, longitude, management_hostname, requested_metadata, requested_metrics, available_values 
        FROM Analytics.devices;"
    )
    .fetch_all(&mut **conn)
    .await
    .map_err(|e| {
        println!("[ERROR][DB]Failed to SELECT devices from database with error = '{}'", &e.to_string());
        AegisError::Sql(e)
    })?;

    let cache = Cache::instance();

    let mut devices = HashMap::new();
    for row in rows {
        let device_id = row.device_id;

        let config = DeviceConfiguration {
            requested_metadata: parse_json_array(Some(row.requested_metadata)),
            requested_metrics: parse_json_array (Some(row.requested_metrics)),
            available_values: parse_json_array(row.available_values),
            data_sources: datasources.get(&row.device_id).unwrap_or(&HashSet::new()).clone(),
        };

        let old_device = cache.get_device(device_id).await;
        let old_state = old_device.map(|d| d.state).unwrap_or(DeviceStatus::empty());

        let device = Device {
            device_id,
            device_name: row.device_name.unwrap_or("Unnamed device".to_owned()),
            latitude: row.latitude,
            longitude: row.longitude,
            management_hostname: row.management_hostname,
            configuration: config,
            state: old_state
        };

        devices.insert(device_id, device);
    }

    Ok(devices)
}


pub async fn query_links(conn: &mut PoolConnection<Postgres>) -> Result<HashMap<LinkId, Link>, AegisError> {
    let rows = sqlx::query_as!(
        Link,
        r#"SELECT link_id, side_a, side_b, side_a_iface, side_b_iface, link_type::TEXT as "link_type: LinkType", link_subtype FROM Analytics.links;"#
    )
    .fetch_all(&mut **conn)
    .await
    .map_err(AegisError::Sql)?;

    let mut links = HashMap::new();
    for row in rows {
        links.insert(row.link_id, row);
    }

    Ok(links)
}

pub async fn query_groups(conn: &mut PoolConnection<Postgres>) -> Result<HashMap<GroupId, Group>, AegisError>{
    let rows = sqlx::query_as!(
        Group,
        r#"
            SELECT g.group_id, g.group_name as name, g.is_display_group, array_agg(gm.item_id) as members
            FROM Analytics.groups as g
            JOIN Analytics.group_members gm on gm.group_id = g.group_id
            GROUP BY g.group_id, g.group_name;
        "#
    )
    .fetch_all(&mut **conn)
    .map_err(AegisError::Sql)
    .await?;

    let mut groups = HashMap::new();

    for group in rows {
        groups.insert(group.group_id, group);
    }

    Ok(groups)
}