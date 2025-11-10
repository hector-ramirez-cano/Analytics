use std::collections::{HashMap, HashSet};

use tokio::sync::mpsc;

use crate::controller::get_operations::api_get_topology;
use crate::model::cache::Cache;
use crate::model::db::operations::dashboard_operations::get_dashboards_as_json;
use crate::model::db::operations::influx_operations::{self, InfluxFilter};
use crate::model::facts::generics::Metrics;


#[derive(serde::Deserialize)]
pub struct WsMsg { 
    #[serde(rename = "type")]
    pub kind: String,
    
    #[serde(rename="msg")]
    pub body: serde_json::Value 
}

impl WsMsg {
    pub fn inner(self) -> Option<WsMsg> {
        let in_type = self.body.get("type")?.as_str()?.to_owned();
        let in_msg = self.body.get("msg")?.to_owned();

        Some(WsMsg{
            kind: in_type,
            body: in_msg
        })
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
    let msg = format!(r#""type":"{msg_type}", "msg": {msg}"#);

    if let Err(e) = data_to_socket.send(msg).await {
        let msg = format!("Encountered error = '{e}' while sending message='{msg_type}'");
        ws_send_error_msg(data_to_socket, &msg).await;
    }

}

pub async fn ws_get_topology(data_to_socket: &mut mpsc::Sender<String>, pool: &rocket::State<sqlx::PgPool>) -> Result<(), ()>  {
    let topology = api_get_topology(pool).await.map_err(|_| ())?;

    ws_send_msg(data_to_socket, "topology", &topology).await;
    
    Ok(())
}

pub async fn ws_get_dashboards(data_to_socket: &mut mpsc::Sender<String>, pool: &rocket::State<sqlx::PgPool>) -> Result<(), ()> {
    let dashboards = get_dashboards_as_json(pool).await?;
    let dashboards = serde_json::to_string(&dashboards.values().collect::<Vec<_>>());
    
    match dashboards {
        Ok(dashboards) => { ws_send_msg(data_to_socket, "dashboard", &dashboards).await },
        Err(e) => { ws_send_error_msg(data_to_socket, &e.to_string()).await }
    }

    Ok(())
}

pub async fn ws_query_facts(data_to_socket: &mut mpsc::Sender<String>, msg_in: WsMsg) -> Option<()> {
    let original_starwalker = &msg_in.kind.clone();

    let msg = msg_in.inner()?;
    let mut facts = msg.body.get("facts")?.to_owned();
    let mut device_ids = msg.body.get("device-ids")?.to_owned();
    
    // Failsafe, convert into array
    if facts.is_string() {
        facts = serde_json::json!([&facts]);
    }

    // Failsafe, convert into array
    if device_ids.is_number() {
        device_ids = serde_json::json!([&device_ids]);
    }

    // Failsafe, if device_ids contains groups, replace with devices, otherwise, extract device ids
    let mut devices = Vec::<i64>::new();
    let cache = Cache::instance();
    for device in device_ids.as_array()? {
        let id = match device.as_i64() { Some(v) => v, None => continue };
        if cache.has_group(id).await {
            devices.extend(cache.get_group_members(id).await?);
        } else if cache.has_device(id).await {
            devices.push(id);
        } else {} // Explicitly do nothing 
    }

    // Extract facts
    let mut extracted : Metrics = HashMap::new();
    let facts : HashSet<String> = facts.as_array()?.iter().map(|s| s.as_str().unwrap_or("").to_owned()).collect();
    for device_id in devices {
        // Filter and extract facts
        let hostname = match cache.get_device_hostname(device_id).await { Some(v) => v, None => continue };
        let extracted_facts = match cache.get_facts(&hostname, &facts).await { Some(v) => v, None => continue };
        
        extracted.insert(hostname, extracted_facts);
    }

    let msg = serde_json::json!({
        "type": original_starwalker,
        "msg": extracted
    });
    data_to_socket.send(msg.to_string()).await.ok()?;


    Some(())
}

// TODO: REMOVE All the option return types;
pub async fn ws_query_metrics(data_to_socket: &mut mpsc::Sender<String>, influx_client: &influxdb2::Client, msg: WsMsg) -> Option<()> {
    let filters = match InfluxFilter::from_json(&msg.body) {
        Some(f) => f,
        None => {
            let e = format!("[INFLUX] Failed to query metrics. Filters could not be obtained from message 'msg', parsed from = '{}'", &msg.body);
            ws_send_error_msg(data_to_socket, &e).await;
            return None
        }
    };

    let result = influx_operations::get_metric_data(influx_client, &filters).await;

    let msg = serde_json::json!({
        "type": "metrics",
        "msg": result
    });

    match data_to_socket.send(msg.to_string()).await {
        Ok(_) => return Some(()),
        Err(e) => {
            log::error!("[ERROR][WS][METRICS] Failed to send metrics message with e = {}, msg='{}'", e.to_string(), msg.to_string())
        }
    }

    Some(())
}