

use std::sync::Arc;

use crate::model::{cache::Cache, db, facts::{baseline::BaselineCache}};
use crate::types::{Metrics, Status};

async fn update_cache(baseline_cache: &Arc<BaselineCache>, forced: bool) {
    use db::operations::influx_operations::get_baseline_metrics;
    if let Some(last_update_guard) = baseline_cache.try_claim_update(forced).await {
        log::info!("[INFO ][FACTS][BASELINE][CACHE] Updating Baseline cache!");
        let device_hostnmame_maps = Cache::instance().get_device_hostnames().await;

        let device_hostname_map = match device_hostnmame_maps {
            Some(d) => d,
            None => {
                log::warn!("[WARN ][FACTS][BASELINE] Cache update failed to read device hostnames. Last values will be used, and this one will be ignored...");
                return
            }
        };

        let metric_set = get_baseline_metrics(&baseline_cache.influx_client, &device_hostname_map).await;

        if metric_set.is_empty() {
            log::warn!("[WARN ][FACTS][BASELINE] Cache update failed. Baseline metrics was empty. Last value will be used, and this one will be ignored...");
            return;
        }
        
        baseline_cache.update_metrics(last_update_guard, metric_set).await;

        log::info!("[INFO ][FACTS][BASELINE][CACHE] Finished updating baseline!");
    }
}

pub async fn gather_facts() -> (Metrics, Status) {
    log::info!("[INFO ][FACTS][BASELINE] Starting baseline gathering");

    let cache = BaselineCache::instance();

    update_cache(&cache, false).await;
    let metrics = cache.metrics.read().await;

    (metrics.0.clone(), Status::new())
}

pub fn init(influx_client: &influxdb2::Client) {
    BaselineCache::init(influx_client);
}