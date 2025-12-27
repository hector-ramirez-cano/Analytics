use rocket::response::status;
use tokio::sync::mpsc::{self, Sender};
use rocket::futures::SinkExt;
use rocket::{State, response};
use rocket::futures::stream::{SplitSink, SplitStream};
use rocket::{futures::StreamExt, get, post};
use rocket_ws::{Message, WebSocket, stream::DuplexStream};
use tokio::task::JoinHandle;

use crate::alerts::{AlertEvent, AlertFilters};
use crate::alerts::alert_backend::AlertBackend;
use crate::config::Config;
use crate::controller::get_operations::{self, api_get_topology};
use crate::controller::post_operations;
use crate::controller::ws_operations::{WsMsg, ws_alerts_rt, ws_check_backend_ws, ws_device_health_rt, ws_get_dashboards, ws_get_topology, ws_get_topology_view, ws_handle_alerts, ws_handle_syslog, ws_query_facts, ws_query_metadata, ws_query_metrics, ws_send_error_msg, ws_syslog_rt};
use crate::model::facts::fact_gathering_backend::{FactGatheringBackend, FactMessage};
use crate::syslog::{SyslogFilters, SyslogMessage};
use crate::syslog::syslog_backend::SyslogBackend;

//  ________                  __                      __              __
// /        |                /  |                    /  |            /  |
// $$$$$$$$/  _______    ____$$ |  ______    ______  $$/  _______   _$$ |_    _______
// $$ |__    /       \  /    $$ | /      \  /      \ /  |/       \ / $$   |  /       |
// $$    |   $$$$$$$  |/$$$$$$$ |/$$$$$$  |/$$$$$$  |$$ |$$$$$$$  |$$$$$$/  /$$$$$$$/
// $$$$$/    $$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |$$ |  $$ |  $$ | __$$      \
// $$ |_____ $$ |  $$ |$$ \__$$ |$$ |__$$ |$$ \__$$ |$$ |$$ |  $$ |  $$ |/  |$$$$$$  |
// $$       |$$ |  $$ |$$    $$ |$$    $$/ $$    $$/ $$ |$$ |  $$ |  $$  $$//     $$/
// $$$$$$$$/ $$/   $$/  $$$$$$$/ $$$$$$$/   $$$$$$/  $$/ $$/   $$/    $$$$/ $$$$$$$/
//                               $$ |
//                               $$ |
//                               $$/
#[get("/heartbeat")]
pub fn heartbeat() -> &'static str {
    #[cfg(debug_assertions)] {print!("[DEBUG]Heartbeat!");}
    "Bip bop"
}

#[get("/api/reload_config")]
pub async fn get_reload_config() -> status::Custom<RocketJson>{
    match Config::reload() {
        Some(_) => {
            let ok_body = serde_json::json!({
                "code": 200,
                "message": "Success"
            });

            status::Custom(rocket::http::Status::Ok, RocketJson::from(ok_body))
        },
        None => {
            let err_body = serde_json::json!({
                "code": 500,
                "message": "Failed to load rules"
            });

            status::Custom(rocket::http::Status::InternalServerError, RocketJson::from(err_body))
        },
    }
}

#[get("/api/topology")]
pub async fn get_topology(pool: &State<sqlx::PgPool>) -> Result<response::content::RawJson<String>, rocket::http::Status> {
    #[cfg(debug_assertions)] {log::debug!("[DEBUG]Get topology!");}
    
    let topology = api_get_topology(pool).await.map_err(|_|rocket::http::Status::BadRequest)?;
    let topology = topology.to_string();

    Ok(response::content::RawJson(topology))
}

type RocketJson = rocket::serde::json::Json<serde_json::Value>;
#[get("/api/rules")]
pub async fn get_rules() -> status::Custom<RocketJson> {
    let rules = get_operations::api_get_rules().await;

    match rules {
        Ok(json) => status::Custom(rocket::http::Status::Ok, RocketJson::from(json)),
        Err(e) => {
            let err_body = serde_json::json!({
                "code": 500,
                "message": "Failed to load rules"
            });

            status::Custom(e, RocketJson::from(err_body))
        }
    }
}

#[post("/api/configure", data = "<data>")]
pub async fn api_configure(data: RocketJson, pool: &State<sqlx::PgPool>) -> status::Custom<RocketJson> {
    
    #[cfg(debug_assertions)] {
        log::info!("[INFO ][API][RX] {}", data.0);
    }

    if !Config::instance().get("backend/controller/configure/enabled", "/").unwrap_or(false) {
        log::warn!("[WARN ][API] Tried to configure, while read-only!");

        let err_body = serde_json::json!({
            "code": "403",
            "message": "Cannot make changes while backend is in read only mode!"
        });
        return status::Custom(rocket::http::Status::BadRequest, RocketJson::from(err_body));
    }

    match &data.0 {
        serde_json::Value::Object(map) => {
            if map.is_empty() {
                let err_body = serde_json::json!({
                    "code": "400",
                    "message": "Malformed Request: Content is empty"
                });
                return status::Custom(rocket::http::Status::BadRequest, RocketJson::from(err_body));
            }
        },

        _ => {
            let err_body = serde_json::json!({
                "code": "400",
                "message": "Malformed Request: Content should be a JSON Object"
            });
            return status::Custom(rocket::http::Status::BadRequest, RocketJson::from(err_body));
        }
    }

    let response = post_operations::api_configure(data.0, pool.inner()).await;

    match response {
        Ok(_) => {
            let ok_body = serde_json::json!({
                "code": "202",
                "message": ""
            });
            status::Custom(rocket::http::Status::Accepted, RocketJson::from(ok_body))
        },
        Err(e) => {
            let err_body = serde_json::json!({
                "code": "400",
                "message": e.0
            });
            log::error!("[POST] Post on 'api/configure' resulted in an error = '{}'", e.0);
            status::Custom(rocket::http::Status::BadRequest, RocketJson::from(err_body))
        }
    }
}

//  __       __            __                                      __                    __
// /  |  _  /  |          /  |                                    /  |                  /  |
// $$ | / \ $$ |  ______  $$ |____    _______   ______    _______ $$ |   __   ______   _$$ |_    _______
// $$ |/$  \$$ | /      \ $$      \  /       | /      \  /       |$$ |  /  | /      \ / $$   |  /       |
// $$ /$$$  $$ |/$$$$$$  |$$$$$$$  |/$$$$$$$/ /$$$$$$  |/$$$$$$$/ $$ |_/$$/ /$$$$$$  |$$$$$$/  /$$$$$$$/
// $$ $$/$$ $$ |$$    $$ |$$ |  $$ |$$      \ $$ |  $$ |$$ |      $$   $$<  $$    $$ |  $$ | __$$      \
// $$$$/  $$$$ |$$$$$$$$/ $$ |__$$ | $$$$$$  |$$ \__$$ |$$ \_____ $$$$$$  \ $$$$$$$$/   $$ |/  |$$$$$$  |
// $$$/    $$$ |$$       |$$    $$/ /     $$/ $$    $$/ $$       |$$ | $$  |$$       |  $$  $$//     $$/
// $$/      $$/  $$$$$$$/ $$$$$$$/  $$$$$$$/   $$$$$$/   $$$$$$$/ $$/   $$/  $$$$$$$/    $$$$/ $$$$$$$/

#[get("/ws/router")]
pub fn ws_router<'a>(ws: WebSocket, pool: &'a State<sqlx::PgPool>, influx_client : &'a State<influxdb2::Client>) -> rocket_ws::Channel<'a> {
    log::info!("[INFO ][WS] Websocket initiated connection, {}", ws.accept_key());
    ws.channel(move |stream| Box::pin(async move {
        let (ws_sender, ws_receiver) = stream.split();

        // Channels (bounded capacity 64)
        let (data_to_socket_tx, data_to_socket_rx) = mpsc::channel::<String>(64);
        let (syslog_rt_tx, syslog_rt_rx) = mpsc::channel::<SyslogMessage>(64);
        let (alerts_rt_tx, alerts_rt_rx) = mpsc::channel::<AlertEvent>(64);
        let (device_health_rt_tx, device_health_rt_rx) = mpsc::channel::<FactMessage>(64);

        // Spawn Sender task
        let tx_task: JoinHandle<()> = tokio::spawn(ws_send_task(ws_sender, data_to_socket_rx));
        let rx_task: JoinHandle<()> = tokio::spawn(ws_receive_task(ws_receiver, data_to_socket_tx.clone(), pool.inner().clone(), influx_client.inner().clone()));

        // Spawn realtime listener tasks
        let syslog_listener_id = SyslogBackend::instance().add_listener(syslog_rt_tx).await;
        let alerts_listener_id = AlertBackend::instance().add_listener(alerts_rt_tx).await;
        let facts_listener_id = FactGatheringBackend::instance().add_listener(device_health_rt_tx).await;
        let syslog_rt_task : JoinHandle<()> = tokio::spawn(ws_syslog_rt(data_to_socket_tx.clone(), syslog_rt_rx));
        let alerts_rt_task : JoinHandle<()> = tokio::spawn(ws_alerts_rt(data_to_socket_tx.clone(), alerts_rt_rx));
        let device_health_rt_task : JoinHandle<()> = tokio::spawn(ws_device_health_rt(data_to_socket_tx.clone(), device_health_rt_rx));

        // Wait until any task finishes, then let the rest drop
        tokio::select! {
            _ = tx_task               => log::warn!("[WARN ][WS] tx_task finished!"),
            _ = rx_task               => log::warn!("[WARN ][WS] rx_task finished!"),
            _ = syslog_rt_task        => log::warn!("[WARN ][WS] syslog_rt_task finished!"),
            _ = alerts_rt_task        => log::warn!("[WARN ][WS] alerts_rt_task finished!"),
            _ = device_health_rt_task => log::warn!("[WARN ][WS] device_health_rt_task finished!"),
        }

        // Explicitly remove the listeners, to avoid having ghost listeners
        SyslogBackend::instance().remove_listener(syslog_listener_id).await;
        AlertBackend::instance().remove_listener(alerts_listener_id).await;
        FactGatheringBackend::instance().remove_listener(facts_listener_id).await;

        Ok(())
    }))
}

async fn ws_send_task(
    mut ws_sender: SplitSink<DuplexStream, Message>,
    mut data_to_socket: mpsc::Receiver<String>,
) {
    while let Some(msg) = data_to_socket.recv().await {
        #[cfg(debug_assertions)] {
            let truncated = msg.chars().take(500).collect::<String>();
            log::info!("\x1b[33m[DEBUG][WS][TX] Sending msg='{}...'\x1b[0m", truncated);}
        let result = ws_sender.send(Message::Text(msg)).await;
        if result.is_err() {
            log::error!("[ERROR][WS][TX] Encountered an error, sender is closing!");
            break;
        }
    }
}

async fn ws_receive_task(
    mut ws_receiver: SplitStream<DuplexStream>,
    mut data_to_socket_tx: Sender<String>,

    pool: sqlx::PgPool,
    influx_client : influxdb2::Client
) {
    // "State" items
    let mut syslog_filters : Option<SyslogFilters> = None;
    let mut alert_filters: Option<AlertFilters> = None;
    
    while let Some(msg) = ws_receiver.next().await {
        match msg {
            Err(e) => {
                log::error!("[ERROR][WS][RX] Encountered an error, receiver is closing!");
                let error = e.to_string();
                if let Err(e) = data_to_socket_tx.send(serde_json::json![{"type": "error", "msg": error}].to_string()).await {
                    let e = e.to_string();
                    log::error!("[ERROR][WS][RX] Failed to send error message to websocket, e = '{e}'")
                }
            },
            Ok(msg) => {
                #[cfg(debug_assertions)] {log::info!("\x1b[35m[DEBUG][WS][RX] Received msg='{}'\x1b[0m", msg);}
                ws_handle_message(&pool, &influx_client, &mut data_to_socket_tx, &mut syslog_filters, &mut alert_filters, msg).await;
            }
        }
    }
}

async fn ws_handle_message(
    pool: &sqlx::PgPool,
    influx_client : &influxdb2::Client,
    
    data_to_socket: &mut mpsc::Sender<String>,

    syslog_filters: &mut Option<SyslogFilters>,
    alert_filters: &mut Option<AlertFilters>,
    
    message: Message
) {
    let msg = message;

    match msg {
        Message::Text(msg) => {
            let msg = serde_json::from_str::<WsMsg>(&msg);
            match msg {
                Err(e) => ws_send_error_msg(data_to_socket, &format!("[BACKEND] Encountered error while handling message='{e}'")).await,
                Ok(msg) => ws_route_message(pool, influx_client, data_to_socket, syslog_filters, alert_filters, msg).await,
            }
        }
        Message::Binary(_) => ws_send_error_msg(data_to_socket, "[BACKEND] Received message via websocket that is not text type. Actual = 'Binary'".to_string().as_str()).await,
        Message::Ping(_) => ws_send_error_msg(data_to_socket, "[BACKEND] Received message via websocket that is not text type. Actual = 'Ping'".to_string().as_str()).await,
        Message::Pong(_) => ws_send_error_msg(data_to_socket, "[BACKEND] Received message via websocket that is not text type. Actual = 'Pong'".to_string().as_str()).await,
        Message::Frame(_) => ws_send_error_msg(data_to_socket, "[BACKEND] Received message via websocket that is not text type. Actual = 'Frame'".to_string().as_str()).await,
        Message::Close(_) => ws_send_error_msg(data_to_socket, "[BACKEND] WebSocket client requested closing. Actual = 'Close'".to_string().as_str()).await,
    }
}

async fn ws_route_message(
    pool: &sqlx::PgPool,
    influx_client : &influxdb2::Client,
    
    data_to_socket: &mut mpsc::Sender<String>,

    syslog_filters: &mut Option<SyslogFilters>,
    alert_filters: &mut Option<AlertFilters>,
    
    msg: WsMsg
) {
    match msg.kind.as_str() {
        "syslog" => ws_handle_syslog(data_to_socket, pool, syslog_filters, msg).await.unwrap_or(()),
        "alerts" => ws_handle_alerts(data_to_socket, pool, alert_filters, msg).await.unwrap_or(()),
        "backend-health-rt" => ws_check_backend_ws(data_to_socket, pool, influx_client).await.unwrap_or(()),
        "dashboards" => ws_get_dashboards(data_to_socket, pool).await.unwrap_or(()),
        "metrics" => ws_query_metrics(data_to_socket, influx_client, msg).await.unwrap_or(()),
        "facts"    => ws_query_facts(data_to_socket, msg).await.unwrap_or(()),
        "metadata" => ws_query_metadata(data_to_socket, msg).await.unwrap_or(()),
        "topology" => ws_get_topology(data_to_socket, pool).await.unwrap_or(()),
        "topology-view" => ws_get_topology_view(data_to_socket, pool).await.unwrap_or(()),
        _ => {
            let kind = msg.kind;
            let err = format!("[ERROR][RX] Received message with no valid type. Actual 'type'={kind}");
            ws_send_error_msg(data_to_socket, &err).await;
        }
    }
}