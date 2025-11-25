use std::{sync::Arc, time::{SystemTime, UNIX_EPOCH}};

use tokio::sync::{RwLockWriteGuard, RwLock};

use crate::model::facts::baseline::{BaselineCache, INSTANCE};
use crate::types::{Metrics, Status};

impl BaselineCache {
    /// Internal constructor. Private
    fn new(influx_client: influxdb2::Client) -> Self {
        Self {
            influx_client,
            metrics: RwLock::new((Metrics::new(), Status::new())),
            last_update: RwLock::new(0) // Begin with last update as EPOCH, to force an initial update
        }
    }

    /// Returns the singleton Arc<BaselineCache>
    pub fn instance() -> Arc<BaselineCache> {
        INSTANCE.get().expect("Baseline backend not initialized").clone()
    }

    pub fn init(influx_client: &influxdb2::Client) {
        let innit_bruv = INSTANCE.set(Arc::new(BaselineCache::new(influx_client.clone())));
        if let Err(_) = innit_bruv {
            println!("[WARN][BASELINE] Baseline backend was init more than once!. Ignoring second init...");
            return;
        }
    }

    pub async fn update_metrics (&self, update_guard : RwLockWriteGuard<'_, u128>, metrics: Metrics) {
        let mut m = self.metrics.write().await;

        m.0 = metrics;

        // update guard goes out of scope, so the lock is lifted
        self.commit_last_update(update_guard).await;
    }

    /// Updates the last_update variable to the current time since EPOCH
    /// A lockGuard is required to commit. The lockGuard is taken into ownership of the function
    /// Meaning that once this function is over, the last_update variable is set, and the lockGuard is released
    async fn commit_last_update(&self, mut guard: RwLockWriteGuard<'_, u128>) {

        let now: u128 = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as u128; // UNIX EPOCH DEATH!
        *guard = now;
    }

    /// Try to claim the update. If this returns Some(write_guard) the caller won the right
    /// to update and holds the write lock on `last_update`. Caller should perform the
    /// refresh while holding the guard and then drop it when done.
    ///
    /// Returns None if an update is not needed (someone else updated recently).
    ///
    /// Considers the cache to "need" an update roughly every 15 minutes
    /// This is chosen, as the tasks execute every two hours.
    /// 15 minutes provides good update lag, while not updating every cycle of the
    /// facts gathering loop
    pub async fn try_claim_update(&self, forced: bool) -> Option<RwLockWriteGuard<'_, u128>> {
        let interval_secs : u128 = 60; // update roughly every 15 minutes.

        // fast read-only check
        let now: u128 = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0) as u128;

        // if the update isn't due, and the caller didn't request a forced update
        let last = *self.last_update.read().await;
        if now.saturating_sub(last) < interval_secs && !forced {
            return None;
        }


        // Acquire write lock (recover from poison if necessary)
        let last_w: RwLockWriteGuard<'_, u128> = self.last_update.write().await;

        // Re-check under the write lock to avoid races
        if now.saturating_sub(*last_w) < interval_secs && !forced {
            // somebody else updated while we were waiting for the write lock
            return None;
        }


        // return the guard so the caller keeps exclusive access while they perform updates
        Some(last_w)
    }

}