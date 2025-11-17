use std::env;

use influxdb2::models::DataPoint;
use rocket::futures::stream;
use sqlx::Postgres;

use crate::{AegisError, config::Config, model::{cache::Cache, db::fetch_topology::{query_devices, query_groups, query_links}, facts::fact_gathering_backend::FactMessage}};

pub async fn update_topology_cache(pool: &sqlx::Pool<Postgres>, forced : bool) -> Result<(), AegisError>{
    if let Some(mut last_update_guard) = Cache::instance().try_claim_update(forced).await {
        println!("[INFO ][CACHE] Updating topology cache!");

        let devices = query_devices(pool).await?;
        let links   = query_links(pool).await?;
        let groups  = query_groups(pool).await?;

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

/// Inserts datapoints into influxdb bucket. 
pub async fn update_device_analytics(influx_client : &influxdb2::Client, message : &FactMessage) {

    log::info!("[INFO ][FACTS] Updating Influx with metrics, from inside the update device analytics function");
    
    let bucket  = Config::instance().get::<String>("backend/controller/influx/bucket", "/");

    let bucket = match bucket {
        Ok(b) => b,
        Err(e) => {
            let cwd = env::current_dir().expect("Failed to get current working directory");
            log::error!("[FATAL] Influx bucket isn't specified in configuration file, e='{e}'\n Expected 'backend/controller/influx/bucket' to be present");
            log::info!("[INFO ] Current working directory was={}", cwd.display());
            log::info!("[INFO ] Current config file was={}", Config::instance().get_curr_config_path());
            panic!("[FATAL] Influx bucket isn't specified in configuration file, e='{e}'\n Expected 'backend/controller/influx/bucket' to be present");
        }
    };

    let mut points = Vec::new();

    #[cfg(debug_assertions)] {
        log::info!("[DEBUG][FACTS][INFLUX] THIS is a bucket = '{}'", &bucket);
        log::info!("[DEBUG][FACTS][INFLUX] Dear god...");
        log::info!("[DEBUG][FACTS][INFLUX] There's more...");
        log::info!("[DEBUG][FACTS][INFLUX] Nooo...");
    }


    for (device, facts) in message {
        let device_id = match Cache::instance().get_device_id(device).await { Some(v) => v, None => continue };

        let mut point = DataPoint::builder("metrics").tag("device_id", device_id.to_string());
        
        #[cfg(debug_assertions)] {
            log::debug!("[DEBUG][FACTS][INFLUX] It contains 'metrics'>'device_id'>{}", device_id.to_string());
        }

        let device_requested_metrics = match Cache::instance().get_device_requested_metrics(device_id).await {
            Some(m) => m, None => continue
        };

        for metric in device_requested_metrics {
            let value = facts.metrics
                .get(&metric);

            let value = match value {
                Some(v) => v, None => continue
            };

            log::debug!("        {} -> {}", &metric, value);
            point = point.field(metric, value.clone());

        }

        let point = match point.build() { Ok(v) => v, Err(_) => continue };
        points.push(point);
    }

    influx_client.write(&bucket, stream::iter(points)).await.unwrap_or_default();
}
