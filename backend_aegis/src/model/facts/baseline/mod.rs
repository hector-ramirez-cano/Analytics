
use std::sync::{Arc, OnceLock};

use tokio::sync::RwLock;

use crate::model::facts::generics::{Metrics, StatusT};

pub mod baseline_cache;
pub mod baseline_backend;

static INSTANCE: OnceLock<Arc<BaselineCache>> = OnceLock::new();
struct BaselineCache {
    influx_client: influxdb2::Client,

    metrics: RwLock<(Metrics, StatusT)>,
    last_update: RwLock<u128> // EPOCH seconds
}
