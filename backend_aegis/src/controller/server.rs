use tokio::sync::mpsc;
use rocket::futures::SinkExt;
use rocket::{State, response};
use rocket::futures::stream::{SplitSink};
use rocket::{futures::StreamExt, get, post};
use rocket_ws::{Message, WebSocket, stream::DuplexStream};
use tokio::task::JoinHandle;

use crate::controller::get_operations::{api_get_topology};
use crate::controller::ws_operations::{WsMsg, ws_get_dashboards, ws_get_topology, ws_query_facts, ws_query_metrics, ws_send_error_msg};

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
    print!("[DEBUG]Heartbeat!");
    return "Bip bop"
}

#[get("/api/topology")]
pub async fn get_topology(pool: &State<sqlx::PgPool>) -> Result<response::content::RawJson<String>, rocket::http::Status> {
    log::debug!("[DEBUG]Get topology!");
    
    let topology = api_get_topology(pool).await?;

    Ok(response::content::RawJson(topology))
}

#[get("/api/rules")]
pub fn get_rules() -> &'static str {
    print!("[DEBUG]get topology!");
    todo!()
}

#[post("/api/configure")]
pub fn api_configure() {
    todo!()
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
        let (ws_sender, mut ws_receiver) = stream.split();

        // Channels (bounded capacity 64)
        let (mut data_to_socket_tx, data_to_socket_rx) = mpsc::channel::<String>(64);

        // Spawn Sender task
        let tx_task: JoinHandle<()> = tokio::spawn(ws_send_task(ws_sender, data_to_socket_rx));
        
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
                    ws_handle_message(pool, influx_client, &mut data_to_socket_tx, msg).await;
                }
            }
        }

        // Wait until any task finishes, then let the rest drop
        tokio::select! {
            _ = tx_task => {},
        }

        Ok(())
    }))
}

async fn ws_send_task(
    mut ws_sender: SplitSink<DuplexStream, Message>,
    mut data_to_socket: mpsc::Receiver<String>,
) {
    while let Some(msg) = data_to_socket.recv().await {
        let result = ws_sender.send(Message::Text(msg)).await;
        if result.is_err() {
            log::error!("[ERROR][WS][TX] Encountered an error, sender is closing!");
            break;
        }
    }
}


async fn ws_handle_message(pool: &State<sqlx::PgPool>, influx_client : &State<influxdb2::Client>, data_to_socket: &mut mpsc::Sender<String>, message: Message) {
    let msg = message;

    match msg {
        Message::Text(msg) => {
            let msg = serde_json::from_str::<WsMsg>(&msg);
            match msg {
                Err(e) => ws_send_error_msg(data_to_socket, &format!("[BACKEND] Encountered error while handling message='{e}'")).await,
                Ok(msg) => ws_route_message(pool, influx_client, data_to_socket, msg).await,
            }
        }

        _ => ws_send_error_msg(data_to_socket, "[BACKEND] Received message via websocket that is not text type").await
    }
}

async fn ws_route_message(pool: &State<sqlx::PgPool>, influx_client : &State<influxdb2::Client>, data_to_socket: &mut mpsc::Sender<String>, msg: WsMsg) {
    match msg.kind.as_str() {
        "syslog" => todo!(),
        "alerts" => todo!(),
        "health-rt" => todo!(),
        "dashboards" => ws_get_dashboards(data_to_socket, pool).await.unwrap_or(()),
        "metrics" => ws_query_metrics(data_to_socket, influx_client, msg).await.unwrap_or(()),
        "facts"    => ws_query_facts(data_to_socket, msg).await.unwrap_or(()),
        "metadata" => ws_query_facts(data_to_socket, msg).await.unwrap_or(()),
        "topology" => ws_get_topology(data_to_socket, pool).await.unwrap_or(()),
        _ => {
            let kind = msg.kind;
            let err = format!("[ERROR][RX] Received message with no valid type. Actual 'type'={kind}");
            ws_send_error_msg(data_to_socket, &err).await;
        }
    }
}