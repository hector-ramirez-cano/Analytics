
use sqlx::{Postgres, pool::PoolConnection};

use crate::{AegisError, model::{cache::Cache, db::fetch_topology::{query_devices, query_groups, query_links}, facts::fact_gathering_backend::FactMessage}};

pub async fn update_topology_cache(conn: &mut PoolConnection<Postgres> , forced : bool) -> Result<(), AegisError>{
    if let Some(mut last_update_guard) = Cache::instance().try_claim_update(forced).await {
        println!("[INFO ][CACHE] Updating topology cache!");

        let devices = query_devices(conn).await?;
        let links   = query_links(conn).await?;
        let groups  = query_groups(conn).await?;

        Cache::instance().update_all(devices, links, groups).await;

        *last_update_guard = Cache::current_epoch_secs();
    }

    Ok(())
}

/// Inserts data that might change infrequently into the Postgres database, and updates local cache of devices
pub async fn update_device_metadata(pool: &sqlx::Pool<Postgres>, msg: &FactMessage) {
    // Set status and available values via exposed fields
    for (hostname, facts) in msg {
        let id = match Cache::instance().get_device_id(&hostname).await {
            Some(id) => id,
            None => {
                log::warn!("[WARN ][FACTS] Tried to update device metadata for a device that doesn't exist in cache. This code should be unreachable!");
                continue;
            }
        };
        // TODO: Make metadata be equal to the filtering of metrics based on selected fields
        let available_values = serde_json::json!(&facts.exposed_fields);
        let metadata = serde_json::json!(&facts.exposed_fields);

        let result = sqlx::query!("UPDATE Analytics.devices 
                    SET metadata = $1, available_values = $2 
                    WHERE device_id = $3",
                    metadata, available_values, id,
                ).execute(pool).await;

        if let Err(e) = result {
            log::error!("[ERROR][FACTS][DB] Failed to update metadata and available values for device = {}. SQL Error = {e}", &hostname);
        }
    }
}