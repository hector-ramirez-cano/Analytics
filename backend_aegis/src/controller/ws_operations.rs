use std::collections::{HashMap, HashSet};

use sqlx::Postgres;
use tokio::sync::mpsc;

use crate::alerts::{AlertEvent, AlertFilters};
use crate::model::cache::Cache;
use crate::model::data::device_state::DeviceStatus;
use crate::model::db::fetch_topology::{get_topology_as_json, get_topology_view_as_json};
use crate::model::db::health_check::check_connections;
use crate::model::db::operations::dashboard_operations::get_dashboards_as_json;
use crate::model::db::operations::influx_operations::{self, InfluxFilter};
use crate::model::facts::fact_gathering_backend::FactMessage;
use crate::model::facts::generics::{DeviceHostname, MetricValue, Metrics};
use crate::syslog::{SyslogFilters, SyslogMessage};


#[derive(serde::Deserialize, serde::Serialize, Debug)]
pub struct WsMsg { 
    #[serde(rename = "type")]
    pub kind: String,
    
    #[serde(rename="msg")]
    pub body: serde_json::Value 
}

impl WsMsg {
    pub fn inner(&self) -> Option<WsMsg> {
        let kind = self.body.get("type")?.as_str()?.to_owned();
        let body = self.body.get("msg")?.to_owned();

        Some(WsMsg{ kind, body })
    }
}

impl ToString for WsMsg {
    fn to_string(&self) -> String {
        serde_json::json!(self).to_string()
    }
}

pub async fn ws_send_error_msg(data_to_socket: &mut mpsc::Sender<String>, msg: &str,) {
    let msg = format!(r#"{{"type": "error", "msg":"{msg}"}}"#);
    log::error!("[ERROR][WS]Encountered error= '{msg}'");
    let result = data_to_socket.send(msg).await;

    if let Err(e) = result {
        log::error!("[ERROR][WS]Failed to notify via websocket='{e}'")
    }
}

pub async fn ws_send_msg(data_to_socket: &mut mpsc::Sender<String>, msg_type: &str, msg: &str) {
    let msg = format!(r#"{{"type":"{msg_type}", "msg": {msg}}}"#);

    if let Err(e) = data_to_socket.send(msg).await {
        let msg = format!("Encountered error = '{e}' while sending message='{msg_type}'");
        ws_send_error_msg(data_to_socket, &msg).await;
    }
}

pub async fn ws_get_topology(data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>) -> Result<(), ()>  {
    let topology = get_topology_as_json(pool).await;
    let topology = match topology {
        Ok(v) => v,
        Err(e) => {
            let e= format!("[BACKEND] Failed to retrieve topology with error = '{e}'");
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    };

    ws_send_msg(data_to_socket, "topology", &topology.to_string()).await;
    
    Ok(())
}

pub async fn ws_get_topology_view(data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>) -> Result<(), ()> {
    let view = get_topology_view_as_json(pool).await;

    let view = match view {
        Ok(v) => v,
        Err(e) => {
            let e= format!("[BACKEND] Failed to retrieve topology view with error = '{e}'");
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    };

    let msg = serde_json::json!({
        "type": "get",
        "msg": view
    });

    Ok(ws_send_msg(data_to_socket, "topology-view", &msg.to_string()).await)
}

pub async fn ws_get_dashboards(data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>) -> Result<(), ()> {
    let dashboards = match get_dashboards_as_json(pool).await {
        Ok(v) => v,
        Err(e) => {
            let e= format!("[BACKEND] Failed to retrieve dashboards with error = '{e}'");
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    };

    let dashboards = serde_json::to_string(&dashboards.values().collect::<Vec<_>>());
    match dashboards {
        Ok(dashboards) => {
            ws_send_msg(data_to_socket, "dashboards", &dashboards).await 
        },
        Err(e) => { ws_send_error_msg(data_to_socket, &e.to_string()).await }
    }

    Ok(())
}

/// Extracts facts from local cache of facts. Fact Gathering loop must've run at least once for this to yield useful results
pub async fn ws_query_facts(data_to_socket: &mut mpsc::Sender<String>, msg: WsMsg) -> Result<(), ()> {
    let original_starwalker = &msg.kind.clone();

    let mut facts = match msg.body.get("facts") {
        Some(f) => f.to_owned(),
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] Facts message contains no 'facts' component to know which facts are being queried").await; 
            return Err(())
        }
    };
    let mut device_ids = match msg.body.get("device-ids") {
        Some(ids) => ids.to_owned(),
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] Facts message contains no 'device-ids' component to know which devices are being queried").await; 
            return Err(())
        }
    };
    
    // Failsafe, convert into array
    if facts.is_string() {
        facts = serde_json::json!([&facts]);
    }

    // Failsafe, convert into array
    if device_ids.is_number() {
        device_ids = serde_json::json!([&device_ids]);
    }

    let device_ids = match device_ids.as_array() {
        Some(ids) => ids,
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] Facts message contains 'device-ids' component but is not of type 'array', 'string' or 'int'").await; 
            return Err(())
        }
    };

    let facts = match facts.as_array() {
        Some(f) => f,
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] Facts message contains 'facts' component, but is not of type 'array'").await;
            return Err(())
        }
    };

    // Failsafe, if device_ids contains groups, replace with devices, otherwise, extract device ids
    let mut devices = Vec::<i64>::new();
    let cache = Cache::instance();
    for device in device_ids {
        let id = match device.as_i64() { Some(v) => v, None => continue };
        if cache.has_group(id).await {
            let members = match cache.get_group_members(id).await {
                Some(m) => m,
                None => {
                    ws_send_error_msg(data_to_socket, 
                        format!("[BACKEND] Facts querying yielded no members for group").as_str()).await; 
                    return Err(())
                }
            };
            devices.extend(members);
        } 
        else if cache.has_device(id).await {
            devices.push(id);
        }
        else {} // Explicitly do nothing 
    }

    // Extract facts
    let mut extracted : Metrics = HashMap::new();
    let facts : HashSet<String> = facts.iter().map(|s| s.as_str().unwrap_or("").to_owned()).collect();
    for device_id in devices {
        // Filter and extract facts
        let hostname = match cache.get_device_hostname(device_id).await { Some(v) => v, None => continue };
        let extracted_facts = match cache.get_facts(&hostname, &facts).await { Some(v) => v, None => continue };
        
        extracted.insert(hostname, extracted_facts);
    }

    dbg!(&original_starwalker);

    let msg = serde_json::json!({
        "type": original_starwalker,
        "msg": {
            "type": "get",
            original_starwalker: facts,
            "msg": extracted,
        }
    });
    if let Err(e) = data_to_socket.send(msg.to_string()).await {
        log::error!("[ERROR][WS] Failed to send message with send error = {e}");
        Err(())
    } else {
        Ok(())
    }
}

/// Extracts metadata from local cache of metadata. Fact Gathering loop must've run at least once for this to yield useful results
pub async fn ws_query_metadata(data_to_socket: &mut mpsc::Sender<String>, msg: WsMsg) -> Result<(), ()> {
    let mut metadata = match msg.body.get("metadata") {
        Some(f) => f.to_owned(),
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] metadata message contains no 'metadata' component to know which metadata are being queried").await; 
            return Err(())
        }
    };
    let mut device_ids = match msg.body.get("device-ids") {
        Some(ids) => ids.to_owned(),
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] Facts message contains no 'device-ids' component to know which devices are being queried").await; 
            return Err(())
        }
    };
    
    // Failsafe, convert into array
    if metadata.is_string() {
        metadata = serde_json::json!([&metadata]);
    }

    // Failsafe, convert into array
    if device_ids.is_number() {
        device_ids = serde_json::json!([&device_ids]);
    }

    let device_ids = match device_ids.as_array() {
        Some(ids) => ids,
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] metadata message contains 'device-ids' component but is not of type 'array', 'string' or 'int'").await; 
            return Err(())
        }
    };

    let metadata = match metadata.as_array() {
        Some(f) => f,
        None => {
            ws_send_error_msg(data_to_socket, "[BACKEND] Metadata message contains 'Metadata' component, but is not of type 'array'").await;
            return Err(())
        }
    };

    // Failsafe, if device_ids contains groups, replace with devices, otherwise, extract device ids
    let mut devices = Vec::<i64>::new();
    let cache = Cache::instance();
    for device in device_ids {
        let id = match device.as_i64() { Some(v) => v, None => continue };
        if cache.has_group(id).await {
            let members = match cache.get_group_device_ids(id).await {
                Some(m) => m,
                None => {
                    ws_send_error_msg(data_to_socket, 
                        format!("[BACKEND] Metadata querying yielded no members for group").as_str()).await; 
                    return Err(())
                }
            };
            devices.extend(members);
        } 
        else if cache.has_device(id).await {
            devices.push(id);
        }
        else {} // Explicitly do nothing 
    }

    // Extract metadata
    let mut extracted : Vec<HashMap<String, MetricValue>> = Vec::new();
    let metadata : HashSet<String> = metadata.iter().map(|s| s.as_str().unwrap_or("").to_owned()).collect();

    for device_id in devices {
        // Filter and extract metadata

        let mut result = HashMap::new();
        let hostname = match cache.get_device_hostname(device_id).await { Some(v) => v, None => continue };
        let extracted_metadata = match cache.get_facts(&hostname, &metadata).await { Some(v) => v, None => continue };

        result.insert("management-hostname".to_string(), MetricValue::String(hostname));
        result.insert("device-id".to_string(), MetricValue::Integer(device_id));
        result.extend(extracted_metadata);
        
        extracted.push(result);
    }

    let msg = serde_json::json!({
        "type": "metadata",
        "msg": {
            "metadata": metadata,
            "msg": extracted,
        }
    });
    if let Err(e) = data_to_socket.send(msg.to_string()).await {
        log::error!("[ERROR][WS] Failed to send message with send error = {e}");
        Err(())
    } else {
        Ok(())
    }
}


/// Queries metrics that come from the InfluxDB metrics storage. Only will be found if that metric for that device is being collected
pub async fn ws_query_metrics(data_to_socket: &mut mpsc::Sender<String>, influx_client: &influxdb2::Client, msg: WsMsg) -> Result<(), ()> {
    let filters = match InfluxFilter::from_json(&msg.body) {
        Some(f) => f,
        None => {
            let e = format!("[INFLUX] Failed to query metrics. Filters could not be obtained from message, parsed from = '{}'", &msg.body);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    };

    let result = influx_operations::get_metric_data(influx_client, &filters).await;

    let msg = serde_json::json!({
        "type": "metrics",
        "metrics": filters.metric,
        "msg": result
    });

    match data_to_socket.send(msg.to_string()).await {
        Ok(_) => return Ok(()),
        Err(e) => {
            log::error!("[ERROR][WS][METRICS] Failed to send metrics message with e = {}, msg='{}'", e.to_string(), msg.to_string())
        }
    }

    Ok(())
}

pub async fn ws_handle_syslog(
    data_to_socket: &mut mpsc::Sender<String>,
    pool: &sqlx::Pool<Postgres>,

    syslog_filters: &mut Option<SyslogFilters>,
    
    msg: WsMsg
) 
-> Result<(), ()> {

    match msg.body {
        serde_json::Value::Null 
        | serde_json::Value::Bool(_) 
        | serde_json::Value::Number(_) 
        | serde_json::Value::String(_) => {
            let e = format!("[ERROR][WS][SYSLOG] Could not parse inner syslog message. Expected message types = (Object, Array). Message was = '{}'", msg.to_string());
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(());
        },
        serde_json::Value::Array(values) => {
            // Convenience handling. If passed as an array, handle it as if it was sent separately
            for value in values {
                let inner = WsMsg { kind: "syslog".to_owned(), body: value  };
                ws_route_syslog(data_to_socket, pool, syslog_filters, inner).await?;
            }
        },
        serde_json::Value::Object(_) => {
            ws_route_syslog(data_to_socket, pool, syslog_filters, msg).await?;
        },
    }

    Ok(())
}

pub async fn ws_handle_alerts(
    data_to_socket: &mut mpsc::Sender<String>,
    pool: &sqlx::Pool<Postgres>,

    alert_filters: &mut Option<AlertFilters>,

    msg: WsMsg
)
-> Result<(), ()> {
    match msg.body {
        serde_json::Value::Null 
        | serde_json::Value::Bool(_) 
        | serde_json::Value::Number(_) 
        | serde_json::Value::String(_) => {
            let e = format!("[ERROR][WS][ALERTS] Could not parse inner Alert message. Expected message types = (Object, Array). Message was = '{}'", msg.to_string());
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(());
        },
        serde_json::Value::Array(values) => {
            // Convenience handling. If passed as an array, handle it as if it was sent separately
            for value in values {
                let inner = WsMsg { kind: "alerts".to_owned(), body: value  };
                ws_route_alerts(data_to_socket, pool, alert_filters, inner).await?;
            }
        },
        serde_json::Value::Object(_) => {
            ws_route_alerts(data_to_socket, pool, alert_filters, msg).await?;
        },
    }

    Ok(())
}

pub async fn ws_check_backend_ws(data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>, influx_client: &influxdb2::Client) -> Result<(), ()>{
    let msg = serde_json::json!({
        "type": "backend-health-rt", "msg": check_connections(pool, influx_client).await
    });

    match data_to_socket.send(msg.to_string()).await {
        Ok(_) => (),
        Err(e) => {
            log::error!("[ERROR][WS][HEALTH] Failed to send message to websocket listener! error= '{e}'. Message will be dropped");
        }
    }

    Ok(())
}


pub async fn ws_syslog_rt(data_to_socket: mpsc::Sender<String>, mut receiver: mpsc::Receiver<SyslogMessage>) {
    loop {
        let msg = match receiver.recv().await {
            None=> return,
            Some(monosodiumglotamate) => monosodiumglotamate
        };

        let msg = serde_json::json!({
            "type": "syslog-rt", "msg": serde_json::json!(msg)
        });

        match data_to_socket.send(msg.to_string()).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][WS][SYSLOG][REALTIME] Failed to send message to websocket listener! error='{e}'. Message will be ignored");
            }
        }
    }
}

pub async fn ws_alerts_rt(data_to_socket: mpsc::Sender<String>, mut receiver: mpsc::Receiver<AlertEvent>) {
    loop {
        let msg = match receiver.recv().await {
            None=> return,
            Some(monosodiumglotamate) => monosodiumglotamate
        };

        let msg = serde_json::json!({
            "type": "alert-rt", "msg": serde_json::json!(msg)
        });

        match data_to_socket.send(msg.to_string()).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][WS][ALERTS][REALTIME] Failed to send message to websocket listener! error='{e}'. Message will be ignored");
            }
        }
    }
}

pub async fn ws_device_health_rt(data_to_socket: mpsc::Sender<String>, mut receiver: mpsc::Receiver<FactMessage>) {
    loop {
        let msg = match receiver.recv().await {
            None=> return,
            Some(monosodiumglotamate) => monosodiumglotamate
        };

        let status: HashMap<DeviceHostname, DeviceStatus> = msg.into_iter().map(|(hostname, facts)| (hostname, facts.status)).collect();

        let msg = serde_json::json!({
            "type": "device-health-rt", "msg": serde_json::json!(status)
        });

        match data_to_socket.send(msg.to_string()).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][WS][DEV-HEALTH][REALTIME] Failed to send message to websocket listener! error='{e}'. Channel will be closed!");
                break;
            }
        }
    }
}


//  _______            __                        __                                                      __              
// /       \          /  |                      /  |                                                    /  |             
// $$$$$$$  | ______  $$/  __     __  ______   _$$ |_     ______          ______    ______    ______   _$$ |_    _______ 
// $$ |__$$ |/      \ /  |/  \   /  |/      \ / $$   |   /      \        /      \  /      \  /      \ / $$   |  /       |
// $$    $$//$$$$$$  |$$ |$$  \ /$$/ $$$$$$  |$$$$$$/   /$$$$$$  |      /$$$$$$  | $$$$$$  |/$$$$$$  |$$$$$$/  /$$$$$$$/ 
// $$$$$$$/ $$ |  $$/ $$ | $$  /$$/  /    $$ |  $$ | __ $$    $$ |      $$ |  $$ | /    $$ |$$ |  $$/   $$ | __$$      \ 
// $$ |     $$ |      $$ |  $$ $$/  /$$$$$$$ |  $$ |/  |$$$$$$$$/       $$ |__$$ |/$$$$$$$ |$$ |        $$ |/  |$$$$$$  |
// $$ |     $$ |      $$ |   $$$/   $$    $$ |  $$  $$/ $$       |      $$    $$/ $$    $$ |$$ |        $$  $$//     $$/ 
// $$/      $$/       $$/     $/     $$$$$$$/    $$$$/   $$$$$$$/       $$$$$$$/   $$$$$$$/ $$/          $$$$/ $$$$$$$/  
//                                                                      $$ |                                             
//                                                                      $$ |                                             
//                                                                      $$/                                              

fn ws_route_syslog_set_filters(syslog_filters: &mut Option<SyslogFilters>, msg: WsMsg) -> Result<(), ()>{
    *syslog_filters = match serde_json::from_value(msg.body) {
        Ok(filters) => Some(filters),
        Err(e) => {
            log::error!("[ERROR][WS][SYSLOG] Failed to parse syslog filters with error = '{e}'");
            return Err(())
        },
    };
    Ok(())
}

async fn ws_route_syslog_check_filters<'a>(data_to_socket: &'a mut mpsc::Sender<String>, filters: &'a mut Option<SyslogFilters>, msg: WsMsg) -> Result<&'a mut SyslogFilters, ()> {
    match filters {
        Some(filters) => Ok(filters),
        None => {
            let e = format!("[ERROR][WS][SYSLOG] Requested size/data before setting filters = '{}'", msg.kind);
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    }
}

async fn ws_route_syslog_request_data(
    data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>, filters: &mut Option<SyslogFilters>, msg: WsMsg
) -> Result<(), ()> {
    let filters = ws_route_syslog_check_filters(data_to_socket, filters, msg).await?;
    let page_size = filters.page_size.unwrap_or(30);
    let data = crate::model::db::operations::syslog_operations::get_rows(page_size, filters, pool).await;

    // TODO: Batch if possible
    // TODO: Add inner type
    for row in data {
        let msg = serde_json::json!({ "type": "syslog", "msg": [row]});

        match data_to_socket.send(msg.to_string()).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][WS][Syslog] Failed to send syslog message with e = {}, msg='{}'", e.to_string(), msg.to_string())
            }
        }
    }

    Ok(())
}

async fn ws_route_syslog_request_size(
    data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>, filters: &mut Option<SyslogFilters>, msg: WsMsg
) -> Result<(), ()> {
    let filters = ws_route_syslog_check_filters(data_to_socket, filters, msg).await?;

    let size = crate::model::db::operations::syslog_operations::get_row_count(filters, &pool).await;

    let msg = serde_json::json!({
        "type": "syslog",
        "msg": {
            "type": "request-size",
            "count": size,
        }
    });

    match data_to_socket.send(msg.to_string()).await {
        Ok(_) => return Ok(()),
        Err(e) => {
            log::error!("[ERROR][WS][Syslog] Failed to send syslog message with e = {}, msg='{}'", e.to_string(), msg.to_string())
        }
    }

    Ok(())
}

async fn ws_route_syslog(
    data_to_socket: &mut mpsc::Sender<String>,
    pool: &sqlx::Pool<Postgres>,

    syslog_filters: &mut Option<SyslogFilters>,
    
    msg_in: WsMsg
)
-> Result<(), ()> {
    let msg = msg_in.inner();
    let msg = match msg {
        Some(m) => m,
        None => {
            let e = format!("[ERROR][WS][SYSLOG] Could not parse inner syslog message. Message was = '{}'", msg_in.to_string());
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(());
        }
    };

    match msg.kind.as_str() {
        "set-filters" => ws_route_syslog_set_filters(syslog_filters, msg)?,
        "request-data" => ws_route_syslog_request_data(data_to_socket, pool, syslog_filters, msg).await?,
        "request-size" => ws_route_syslog_request_size(data_to_socket, pool, syslog_filters, msg).await?,
        _ => {
            let e = format!("[ERROR][WS][SYSLOG] Inner syslog message contains invalid type. Expected ('set-filters', 'request-data', request-size') Actual = '{}'", msg.kind);
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    }

    Ok(())
}

fn ws_route_alerts_set_filters(filters: &mut Option<AlertFilters>, msg: WsMsg) -> Result<(), ()>{
    *filters = match serde_json::from_value(msg.body) {
        Ok(filters) => Some(filters),
        Err(e) => {
            log::error!("[ERROR][WS][ALERT] Failed to parse alert filters with error = '{e}'");
            return Err(())
        },
    };
    Ok(())
}

async fn ws_route_alerts_check_filters<'a>(data_to_socket: &'a mut mpsc::Sender<String>, filters: &'a mut Option<AlertFilters>, msg: WsMsg) -> Result<&'a mut AlertFilters, ()> {
    match filters {
        Some(filters) => Ok(filters),
        None => {
            let e = format!("[ERROR][WS][ALERTS] Requested size before setting filters = '{}'", msg.kind);
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    }
}

async fn ws_route_alerts_request_data(
    data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>, filters: &mut Option<AlertFilters>, msg: WsMsg
) -> Result<(), ()> {
    let filters = ws_route_alerts_check_filters(data_to_socket, filters, msg).await?;
    let page_size = filters.page_size.unwrap_or(30);
    
    let data = crate::model::db::operations::alert_operations::get_rows(page_size, filters, pool).await;

    // TODO: Batch if possible
    // TODO: Add inner type
    for row in data {
        let msg = serde_json::json!({ "type": "alerts", "msg": [row]});

        match data_to_socket.send(msg.to_string()).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][WS][Syslog] Failed to send syslog message with e = {}, msg='{}'", e.to_string(), msg.to_string())
            }
        }
    }

    Ok(())
}

async fn ws_route_alerts_request_size(
    data_to_socket: &mut mpsc::Sender<String>, pool: &sqlx::Pool<Postgres>, filters: &mut Option<AlertFilters>, msg: WsMsg
) -> Result<(), ()> {
    let filters = ws_route_alerts_check_filters(data_to_socket, filters, msg).await?;

    
    let size = crate::model::db::operations::alert_operations::get_row_count(filters, &pool).await;

    let msg = serde_json::json!({
        "type": "alerts",
        "msg": {
            "type": "request-size",
            "count": size,
        }
    });

    match data_to_socket.send(msg.to_string()).await {
        Ok(_) => return Ok(()),
        Err(e) => {
            log::error!("[ERROR][WS][Syslog] Failed to send syslog message with e = {}, msg='{}'", e.to_string(), msg.to_string())
        }
    }

    Ok(())
}

async fn ws_route_alerts (
    data_to_socket: &mut mpsc::Sender<String>,
    pool: &sqlx::Pool<Postgres>,

    alert_filters: &mut Option<AlertFilters>,

    msg_in: WsMsg
)
-> Result<(), ()> {

    let msg = msg_in.inner();
    let msg = match msg {
        Some(m) => m,
        None => {
            let e = format!("[ERROR][WS][ALERTS] Could not parse inner alerts message. Message was = '{}'", msg_in.to_string());
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(());
        }
    };

    match msg.kind.as_str() {
        "set-filters" => ws_route_alerts_set_filters(alert_filters, msg)?,
        "request-data" => ws_route_alerts_request_data(data_to_socket, pool, alert_filters, msg).await?,
        "request-size" => ws_route_alerts_request_size(data_to_socket, pool, alert_filters, msg).await?,
        _ => {
            let e = format!("[ERROR][WS][ALERTS] Inner alerts message contains invalid type. Expected ('set-filters', 'request-data', request-size') Actual = '{}'", msg.kind);
            log::error!("{}", e);
            ws_send_error_msg(data_to_socket, &e).await;
            return Err(())
        }
    }

    Ok(())
}