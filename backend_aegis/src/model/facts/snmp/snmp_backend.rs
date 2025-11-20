use crate::{model::cache::Cache, types::{Metrics, Status}};

pub async fn gather_facts(
) -> (Metrics, Status) {
    log::info!("[INFO ][FACTS][SNMP] Starting tree walk...");
    let targets = Cache::instance().snmp_inventory().await;

    // let results = ping_devices(targets).await;

    log::info!("[INFO ][FACTS][SNMP] Tree walk done.");

    (Metrics::new(), Status::new())
}

pub fn init() {

    println!("[INFO ][FACTS][SNMP] Init SNMP backend");
}