use std::env;

use influxdb2::models::DataPoint;
use rocket::futures::stream;

use crate::{config::Config, model::{cache::Cache, db::fetch_topology::{query_devices, query_groups, query_links}, facts::generics::Metrics}};

pub async fn update_topology_cache(pool: &sqlx::PgPool, forced : bool) -> Result<(), rocket::http::Status>{
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

pub async fn update_device_analytics(influx_client : &influxdb2::Client, metrics : &Metrics) {

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

    log::info!("[DEBUG][FACTS][INFLUX] THIS is a bucket = '{}'", &bucket);
    log::info!("[DEBUG][FACTS][INFLUX] Dear god...");
    log::info!("[DEBUG][FACTS][INFLUX] There's more...");
    log::info!("[DEBUG][FACTS][INFLUX] Nooo...");


    for device in metrics {
        let device_id = match Cache::instance().get_device_id(device.0).await { Some(v) => v, None => continue };

        let mut point = DataPoint::builder("metrics").tag("device_id", device_id.to_string());
        
        log::debug!("[DEBUG][FACTS][INFLUX] It contains 'metrics'>'device_id'>{}", device_id.to_string());

        let device_requested_metrics = match Cache::instance().get_device_requested_metrics(device_id).await {
            Some(m) => m, None => continue
        };

        for metric in device_requested_metrics {
            let value = device.1
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
