use serde_json::Map;
use sqlx::Postgres;

use crate::{alerts::{AlertRule, alert_backend::AlertBackend}, misc::hashset_to_json_array, model::{cache::Cache, data::{DataSource, device::Device, group::Group, link::Link, link_type::LinkType}}};

type E = (String, i16);
pub async fn commit(mut data: serde_json::Value, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    // Start a transaction. Either everything succeedes, or it fails altogether
    // once this transaction goes out of scope, if a commit hasn't been performed
    // sqlx will automatically rollback. RAII
    // ain't that neat?
    // TODO: Acquire instead of using the pool for each
    {
        let transaction: sqlx::Transaction<'_, Postgres> = pool.begin().await
            .map_err(|err| (format!("Could not begin commit transaction. Err = '{err}'").to_string(), 500))?;

        let mut data = data.as_object_mut().ok_or(("'data' is not Json Object".to_string(), 400))?;
        
        insert_and_update(&mut data, pool).await?;
        delete_items(&mut data, pool).await?;

        transaction.commit().await.map_err(|err|  (format!("Could not commit transaction, error = '{err}'"), 500))?;
    }
    // End of database transaction block, release transaction

    Cache::instance().update_topology(pool, true).await
        .map_err(|_| ("Could not update topology Cache. Values might be out of sync with database!".to_string(), 500))?;

    AlertBackend::instance().update_ruleset(true).await;

    Ok(())
}

/// Manually inserts or updates devices in the '-changes' fields
async fn insert_and_update(data: &mut serde_json::Map<String, serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    let empty = serde_json::Value::Object(Map::new());
    let topology_changes   = data.remove("topology-changes"  ).unwrap_or(empty.clone());
    let ruleset_changes    = data.remove("ruleset-changes"   ).unwrap_or(empty.clone());
    let mut topology_changes = if let serde_json::Value::Object(v) = topology_changes { v } 
        else { return Err(("topology-changes is found, but it's not object!".to_string(), 400)) };

    let mut ruleset_changes = if let serde_json::Value::Object(v) = ruleset_changes { v } 
        else { return Err(("ruleset-changes is found, but it's not object!".to_string(), 400)) };

    // Update devices
    if let Some(devices) = topology_changes.remove("devices") {
        let devices = if let serde_json::Value::Array(arr) = devices { arr }
            else { return Err(("topology-changes/devices is found, but is not array".to_string(), 400)) };

        update_devices(devices, pool).await?;
    }

    // Update groups
    if let Some(groups) = topology_changes.remove("groups") {
        let groups = if let serde_json::Value::Array(arr) = groups { arr }
            else { return Err(("topology-changes/groups is found, but is not array".to_string(), 400)) };

        update_groups(groups, pool).await?;
    }

    // Update links
    if let Some(links) = topology_changes.remove("links") {
        let links = if let serde_json::Value::Array(arr) = links { arr }
            else { return Err(("topology-changes/links is found, but is not array".to_string(), 400)) };

        update_links(links, pool).await?;
    }

    // Rules
    if let Some(rules) = ruleset_changes.remove("rules") {
        let rules = if let serde_json::Value::Array(arr) = rules { arr }
            else { return Err(("ruleset-changes/rules is found, but is not array".to_string(), 400)) };

        update_rules(rules, pool).await?;
    }

    Ok(())
}

async fn delete_items(data: &mut serde_json::Map<String, serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    let empty = serde_json::Value::Object(Map::new());
    let topology_deletions = data.remove("topology-deletions").unwrap_or(empty.clone());
    let ruleset_deletions  = data.remove("ruleset-deletions" ).unwrap_or(empty.clone());

        
    let mut topology_deletions = if let serde_json::Value::Object(v) = topology_deletions { v } 
        else { return Err(("topology-deletions is found, but it's not object!".to_string(), 400)) };
    let mut ruleset_deletions = if let serde_json::Value::Object(v) = ruleset_deletions { v } 
        else { return Err(("ruleset-deletions found, but it's not object!".to_string(), 400)) };
    if let Some(groups) = topology_deletions.remove("groups") {
        let groups = if let serde_json::Value::Array(arr) = groups { arr }
            else { return Err(("topology-deletions/groups is found, but is not array".to_string(), 400)) };

        delete_groups(groups, pool).await?;
    }

    if let Some(links) = topology_deletions.remove("links") {
        let links = if let serde_json::Value::Array(arr) = links { arr }
            else { return Err(("topology-deletions/links is found, but is not array".to_string(), 400)) };

        delete_links(links, pool).await?;
    }

    if let Some(devices) = topology_deletions.remove("devices") {
        let devices = if let serde_json::Value::Array(arr) = devices { arr }
            else { return Err(("topology-deletions/devices is found, but is not array".to_string(), 400)) };

        delete_devices(devices, pool).await?;
    }

    if let Some(rules) = ruleset_deletions.remove("rules") {
        let rules = if let serde_json::Value::Array(arr) = rules { arr }
            else { return Err(("truleset-deletions/rules is found, but is not array".to_string(), 400)) };

        delete_rules(rules, pool).await?;
    }

    Ok(())
}

/// Updates the devices table with new information
async fn update_devices(devices: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for device in devices {
        let device : Device = serde_json::from_value(device).map_err(|e| (format!("Could not update device. Parsing failed with error = '{e}'"), 400))?;
        let device_name = device.device_name;
        let latitude = device.latitude;
        let longitude = device.longitude;
        let management_hostname = device.management_hostname;
        let requested_metadata = hashset_to_json_array(&device.configuration.requested_metadata);
        let requested_metrics = hashset_to_json_array(&device.configuration.requested_metrics);
        let available_values = hashset_to_json_array(&device.configuration.available_values);

        let result = if device.device_id <= 0 {
            dbg!("Inserting the mfer");
            sqlx::query!("
                INSERT INTO Analytics.devices
                    (device_name, latitude, longitude, management_hostname, requested_metadata, requested_metrics, available_values)
                VALUES
                    ($1, $2, $3, $4, $5, $6, $7)",
                device_name, latitude, longitude, management_hostname, requested_metadata, requested_metrics, available_values,
            ).execute(pool).await
        } else {
            sqlx::query!(
                "UPDATE Analytics.devices
                SET device_name=$1, latitude=$2, longitude=$3, management_hostname=$4, requested_metadata=$5, requested_metrics=$6, available_values=$7
                WHERE device_id =$8",
                device_name, latitude, longitude, management_hostname, requested_metadata, requested_metrics, available_values, device.device_id,
            ).execute(pool).await
        };
        result.map_err(|e| (format!("Failed to update device with SQL Error = '{e}'"), 500))?;

        // Remove all the instances of datasources in normalized table
        // they'll be inserted again. This is done so removing items also has an effect
        let result = sqlx::query!(
            "DELETE FROM Analytics.device_data_sources WHERE device_id = $1", device.device_id
        ).execute(pool).await;
        result.map_err(|e| (format!("Failed to update device with SQL Error = '{e}'"), 500))?;

        // Fresh insertion of data sources
        for datasource in device.configuration.data_sources {
            let result = sqlx::query!("
                INSERT INTO Analytics.device_data_sources
                    (device_id, fact_data_source)
                VALUES
                    ($1, $2)
                ON CONFLICT (device_id, fact_data_source) DO NOTHING",
                device.device_id, datasource as DataSource
            ).execute(pool).await;
            result.map_err(|e| (format!("Failed to update device with SQL Error = '{e}'"), 500))?;
        }
    }
    Ok(())
}

/// Updates the groups table and group_members table with new information
async fn update_groups(groups: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for group in groups {
        let group : Group = serde_json::from_value(group).map_err(|e| (format!("Could not update group. Parsing failed with error = '{e}'"), 400))?;
        if group.group_id <= 0 {
            sqlx::query!("
                INSERT INTO Analytics.groups
                    (group_name, is_display_group)
                VALUES
                    ($1, $2)",
                group.name, group.is_display_group
            ).execute(pool).await
            .map_err(|e| (format!("Could not insert group. SQL Error = '{e}'"), 500))?;
        } else {
            sqlx::query!("
                UPDATE Analytics.groups
                SET group_name = $1, is_display_group = $2
                WHERE group_id = $3",
                group.name, group.is_display_group, group.group_id
            ).execute(pool).await
            .map_err(|e| (format!("Could not update group. SQL Error = '{e}'"), 500))?;

            sqlx::query!(
                "DELETE FROM Analytics.group_members WHERE group_id = $1", group.group_id
            ).execute(pool).await
            .map_err(|e| (format!("Could not delete group members during update. SQL Error = '{e}'"), 500))?;
        }

        for member in group.members.unwrap_or(Vec::new()) {
            sqlx::query!("
                INSERT INTO Analytics.group_members
                    (group_id, item_id)
                VALUES
                    ($1, $2)
                ON CONFLICT (group_id, item_id) DO NOTHING",
                group.group_id, member
            ).execute(pool).await
            .map_err(|e| (format!("Could not update group members durin gupdate. SQL Error = '{e}'"), 500))?;
        }
    }

    Ok(())
}

/// Updates the links table with new information
async fn update_links(links: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for link in links {
        let link : Link = serde_json::from_value(link).map_err(|e| (format!("Could not update link. Parsing failed with error = '{e}'"), 500))?;
        
        if link.link_id <= 0 {
            sqlx::query!("
                INSERT INTO Analytics.links
                    (side_a, side_b, side_a_iface, side_b_iface, link_type, link_subtype)
                VALUES
                    ($1, $2, $3, $4, $5, $6)",
                link.side_a, link.side_b, link.side_a_iface, link.side_b_iface, link.link_type as LinkType, link.link_subtype
            ).execute(pool).await
            .map_err(|e| (format!("Could not insert link. SQL Error = '{e}'"), 500))?;
        } else {
            sqlx::query!("
            UPDATE Analytics.links
                SET side_a = $1, side_b = $2, side_a_iface = $3,
                    side_b_iface = $4, link_type = $5, link_subtype = $6
                WHERE link_id = $7",
                link.side_a, link.side_b, link.side_a_iface,
                link.side_b_iface, link.link_type as LinkType, link.link_subtype,
                link.link_id
            ).execute(pool).await
            .map_err(|e| (format!("Could not update link. SQL Error = '{e}'"), 500))?;
        }
    }
    Ok(())
}

/// Updates the alert_rules table with new information
async fn update_rules(rules: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for rule_in in rules {
        let definition = rule_in.get("rule-definition")
        .ok_or((format!("Could not update rule. 'rule-definition' is missing for rule"), 400))?.clone();
    
    
        let rule : AlertRule = serde_json::from_value(rule_in)
            .map_err(|e| (format!("Could not update rule. Parsing failed with error = '{e}'"), 400))?;

        log::info!("[DEBUG][DB][UPDATES] Updating rule= {}", rule.rule_id);

        if rule.rule_id <= 0 {
            sqlx::query!("
                INSERT INTO Analytics.alert_rules
                    (rule_name, requires_ack, rule_definition)
                VALUES
                    ($1, $2, $3)",
                rule.name, rule.requires_ack, definition
            ).execute(pool).await
            .map_err(|e| (format!("Could not insert rule. SQL error = '{e}'"), 500))?;
        } else {
            log::info!("[DEBUG][DB][UPDATES] Definition= {}", &definition);
            sqlx::query!("
                UPDATE Analytics.alert_rules
                SET rule_name=$1, requires_ack=$2, rule_definition=$3
                WHERE rule_id =$4",
                rule.name, rule.requires_ack, definition, rule.rule_id
            ).execute(pool).await
            .map_err(|e| (format!("Could not update rule. SQL Error = '{e}'"), 500))?;
        }
    }
    
    Ok(())
}

/// Deletes any entries in the groups table, that match the passed values
async fn delete_groups(groups: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for group in groups {
        let id = group.get("id")
            .ok_or( ("Could not delete group. 'id' is not present".to_string(), 400))?;
        let id = id.as_i64()
            .ok_or(("Could not delete group. 'id' is not of type i64".to_string(), 400))?;

        sqlx::query!("DELETE FROM Analytics.groups WHERE group_id = $1", id).execute(pool).await
            .map_err(|e| (format!("Could not delete group. SQL Error = '{e}'"), 500))?;
    }
    Ok(())
}

/// Deletes any entries in the links table, that match the passed values
async fn delete_links(links: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for link in links {
        let id = link.get("id")
            .ok_or( ("Could not delete link. 'id' is not present".to_string(), 400))?;
        let id = id.as_i64()
            .ok_or(("Could not delete link. 'id' is not of type i64".to_string(), 400))?;

        sqlx::query!("DELETE FROM Analytics.links WHERE link_id = $1", id).execute(pool).await
            .map_err(|e| (format!("Could not delete link. SQL Error = '{e}'"), 500))?;
    }
    Ok(())
}

/// Deletes any entries in the device table, that match the passed values
async fn delete_devices(devices: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for device in devices {
        let id = device.get("id")
            .ok_or( ("Could not delete device. 'id' is not present".to_string(), 400))?;
        let id = id.as_i64()
            .ok_or(("Could not delete device. 'id' is not of type i64".to_string(), 400))?;

        sqlx::query!("DELETE FROM Analytics.devices WHERE device_id = $1", id).execute(pool).await
            .map_err(|e| (format!("Could not delete device. SQL Error = '{e}'"), 500))?;
    }
    Ok(())
}

/// Deletes any entries in the alert_rules table, that match the passed values
/// Do note that deleting any rules will not affect the persistance of rule events, but they'll point to a non-existant rule
async fn delete_rules(rules: Vec<serde_json::Value>, pool: &sqlx::Pool<Postgres>) -> Result<(), E> {
    for rule in rules {
        let id = rule.get("id")
            .ok_or( ("Could not delete rule. 'id' is not present".to_string(), 400))?;
        let id = id.as_i64()
            .ok_or(("Could not delete rule. 'id' is not of type i64".to_string(), 400))?;

        sqlx::query!("DELETE FROM Analytics.alert_rules WHERE rule_id = $1", id).execute(pool).await
            .map_err(|e| (format!("Could not delete rule. SQL Error = '{e}'"), 500))?;
    }
    Ok(())
}
