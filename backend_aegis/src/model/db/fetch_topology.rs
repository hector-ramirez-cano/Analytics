use std::collections::{HashMap, HashSet};

use rocket::futures::TryFutureExt;
use serde_json::Value;

use crate::model::cache::Cache;
use crate::model::data::device::Device;
use crate::model::data::link::Link;
use crate::model::data::group::Group;
use crate::model::data::link_type::LinkType;
use crate::model::data::device_configuration::DeviceConfiguration;
use crate::model::data::data_source::DataSource;
use crate::model::db::update_topology::update_topology_cache;

#[derive(sqlx::FromRow)]
struct DeviceDataSource {
    device_id: i64,
    fact_data_source: DataSource,
}

impl From<Option<DeviceDataSource>> for DeviceDataSource {
    fn from(value: Option<DeviceDataSource>) -> Self {
        value.unwrap_or(DeviceDataSource { device_id: 0, fact_data_source: DataSource::Icmp })
    }
}

pub async fn get_topology_as_json_str(pool: &sqlx::PgPool) -> Result<String, rocket::http::Status> {
    // Update before returning, if needed
    update_topology_cache(pool, false).await?;

    // returning from Cache, Cache handles it
    Cache::instance().as_json().map_err(|_| rocket::http::Status::InternalServerError).await
}

fn parse_json_array(field: Option<Value>) -> HashSet<String> {
    match field {
        Some(Value::Array(arr)) => arr
            .into_iter()
            .filter_map(|v| v.as_str().map(String::from))
            .collect(),
        _ => HashSet::new(),
    }
}

pub async fn query_devices(pool: &sqlx::PgPool) -> Result<HashMap<i64, Device>, rocket::http::Status>{
    // Query datasources
    let mut datasources : HashMap<i64, HashSet<DataSource>> = HashMap::new();
    let rows = sqlx::query_as!(
        DeviceDataSource, 
        r#"
            SELECT device_id,
                fact_data_source::TEXT as "fact_data_source: DataSource"
            FROM Analytics.device_data_sources
            "#
    )
        .fetch_all(&*pool)
        .await
        .map_err(|_| rocket::http::Status::InternalServerError)?;

    for row in rows {
        let device_id = row.device_id;

        datasources.entry(device_id)
            .or_insert_with(HashSet::new)
            .insert(row.fact_data_source);
    }
    
    // Query devices themselves
    let rows = sqlx::query!(
        "SELECT Analytics.devices.device_id, device_name, latitude, longitude, management_hostname, requested_metadata, requested_metrics, available_values 
        FROM Analytics.devices;"
    )
    .fetch_all(&*pool)
    .await
    .map_err(|e| {
        let e = e.to_string();
        log::error!("[DB]Failed to SELECT devices from database with error = '{e}'");
        rocket::http::Status::InternalServerError
    })?;

    let mut devices = HashMap::new();
    for row in rows {
        let device_id = row.device_id;

        let config = DeviceConfiguration {
            requested_metadata: parse_json_array(Some(row.requested_metadata)),
            requested_metrics: parse_json_array (Some(row.requested_metrics)),
            available_values: parse_json_array(row.available_values),
            data_sources: datasources.get(&row.device_id).unwrap_or(&HashSet::new()).clone(),
        };

        let device = Device {
            device_id: device_id.into(),
            device_name: row.device_name.unwrap_or("Unnamed device".to_owned()),
            latitude: row.latitude,
            longitude: row.longitude,
            management_hostname: row.management_hostname,
            configuration: config,
        };

        devices.insert(device_id.into(), device);
    }

    Ok(devices)
}


pub async fn query_links(pool: &sqlx::PgPool) -> Result<HashMap<i64, Link>, rocket::http::Status> {
    let rows = sqlx::query_as!(
        Link,
        r#"SELECT link_id, side_a, side_b, side_a_iface, side_b_iface, link_type::TEXT as "link_type: LinkType", link_subtype FROM Analytics.links;"#
    )
    .fetch_all(&*pool)
    .map_err(|_| rocket::http::Status::InternalServerError)
    .await?;

    let mut links = HashMap::new();
    for row in rows {
        links.insert(row.link_id, row);
    }

    Ok(links)
}

pub async fn query_groups(pool: &sqlx::PgPool) -> Result<HashMap<i64, Group>, rocket::http::Status>{
    let rows = sqlx::query_as!(
        Group,
        r#"
            SELECT g.group_id, g.group_name as name, g.is_display_group, array_agg(gm.item_id) as members
            FROM Analytics.groups as g
            JOIN Analytics.group_members gm on gm.group_id = g.group_id
            GROUP BY g.group_id, g.group_name;
        "#
    )
    .fetch_all(&*pool)
    .map_err(|_| rocket::http::Status::InternalServerError)
    .await?;

    let mut groups = HashMap::new();

    for group in rows {
        groups.insert(group.group_id, group);
    }

    Ok(groups)
}