#[macro_use] extern crate rocket;

use backend_aegis::alerts::alert_backend::AlertBackend;
use backend_aegis::model::cache::Cache;
use backend_aegis::model::facts::fact_gathering_backend::FactGatheringBackend;
use backend_aegis::syslog::syslog_backend::SyslogBackend;
use sqlx::{Pool, Postgres};
use std::env;

use backend_aegis::controller::server;
use backend_aegis::config::Config;
use backend_aegis::model::db::pools::{init_influx_client, init_posgres_pool};

#[launch]
async fn launch() -> _ {
    log::set_max_level(log::LevelFilter::Debug);

    // CWD, to know where files will be looked for
    // if the current directory can't be determined for some weird reason, it _must_ panic
    let cwd = env::current_dir().expect("[FATAL]Failed to get current working directory");
    println!("cwd: {}", cwd.display());

    // init - failfast if something can't init
    // expect: failfast on postgres client. It _must_ be present
    Config::init();
    let postgres_pool : Pool<Postgres> = init_posgres_pool().await.expect("Postgres database could not init");
    let influx_client : influxdb2::Client = init_influx_client().await;
    Cache::init(&postgres_pool).await;
    AlertBackend::init(&postgres_pool).await;
    FactGatheringBackend::init(&influx_client);
    SyslogBackend::init();

    // start worker tasks
    FactGatheringBackend::spawn_gather_task(postgres_pool.clone(), influx_client.clone()).await;
    SyslogBackend::spawn_gather_task(postgres_pool.clone()).await;

    rocket::build()
        .manage(postgres_pool)
        .manage(influx_client)
        .mount("/", 
            routes![
                // API HTTP Endpoints
                server::heartbeat, 
                server::get_topology,
                server::get_rules,
                server::api_configure,

                // Websocket
                server::ws_router,
            ]
        )
        
}
