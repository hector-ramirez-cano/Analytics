use std::env;
use sqlx::Postgres;
use sqlx::Pool;
use sqlx::postgres::PgPoolOptions;
use crate::config::Config;

fn handle_fatal(message: &str) -> Result<(), ()>{
    let cwd = env::current_dir().expect("Failed to get current working directory");
    log::error!("{}", message);
    log::info!("[INFO ] Current working directory was={}", cwd.display());
    log::info!("[INFO ] Current config file was={}", Config::instance().get_curr_config_path());
    panic!("{}", message);
}

pub async fn init_posgres_pool() -> Result<Pool<Postgres>, sqlx::Error> {
    let config = Config::instance();

    let port = config.get_value_opt("backend/controller/postgres/port", "/")
        .unwrap_or_default().as_u64().unwrap_or(5432);
    
    let binding = config.get_value_opt("backend/controller/postgres/hostname", "/")
        .unwrap_or_default();
    let host = binding.as_str().expect("Database hostname not found in configuration");
    
    let binding = config.get_value_opt("backend/controller/postgres/name", "/")
        .unwrap_or_default();
    let dbcooper = binding.as_str().expect("Database name not found in configuration");
    
    let binding = config.get_value_opt("backend/controller/postgres/user", "/")
        .unwrap_or_default();
    let user = binding.as_str().expect("Database user name not found in configuration");
    
    let binding = config.get_value_opt("backend/controller/postgres/password", "/")
        .unwrap_or_default();
    let pass = binding.as_str().expect("user pass not found in configuration");
    
    let binding = config.get_value_opt("backend/controller/postgres/schema", "/")
        .unwrap_or_default();
    let schema = binding.as_str().unwrap_or("postgresql://");

    let conn_url = format!("{schema}{user}:{pass}@{host}:{port}/{dbcooper}");

    let pool: Pool<Postgres> = PgPoolOptions::new()
        .max_connections(16)
        .connect(&conn_url)
        .await?;

    sqlx::query!("SET TIMEZONE TO 'UTC';").execute(&pool).await?;

    Ok(pool)
}

pub async fn init_influx_client() -> influxdb2::Client {
    let config = Config::instance();

    let port = match config.get::<i16>("backend/controller/influx/port", "/")  {
        Ok(v) => v,
        Err(_) => {
            println!("[WARN ][DB] Influx port not found in configuration, fallback to TCP:8086");
            8086
        }
    };
    let schema = match config.get::<String>("backend/controller/influx/schema", "/")  {
        Ok(v) => v,
        Err(_) => {
            println!("[WARN ][DB] Influx schema not found in configuration, fallback to 'http://'");
            "http://".to_string()
        }
    };

    let host = match config.get::<String>("backend/controller/influx/hostname", "/") {
        Ok(v) => v, Err(_) => { handle_fatal("[FATAL] Failed to create Influx Client. Hostname is not found in config file").unwrap(); unreachable!() } ,
    };
    let org = match config.get::<String>("backend/controller/influx/org", "/") {
        Ok(v) => v, Err(_) => { handle_fatal("[FATAL] Failed to create Influx Client. Org name is not found in config file").unwrap(); unreachable!() } ,
    };
    let token = match config.get::<String>("backend/controller/influx/token", "/") {
        Ok(v) => v, Err(_) => { handle_fatal("[FATAL] Failed to create Influx Client. Token is not found in config file").unwrap(); unreachable!() } ,
    };
    let _bucket = match config.get::<String>("backend/controller/influx/bucket", "/") {
        Ok(v) => v, Err(_) => { handle_fatal("[FATAL] Failed to create Influx Client. Bucket is not found in config file").unwrap(); unreachable!() } ,
    };

    let conn_url = format!("{schema}{host}:{port}");

    let client = influxdb2::Client::new(
        conn_url,
        org,
        token
    );

    client
}