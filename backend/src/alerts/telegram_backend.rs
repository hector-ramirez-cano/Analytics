use std::{collections::HashSet, sync::{Arc, OnceLock}};


use chrono_tz::Tz;
use serde::{Deserialize, Serialize};
use tgbot::{api::Client, handler::{LongPoll, UpdateHandler}, types::{ChatPeerId, ParseMode}};
use tokio::sync::{RwLock, mpsc::Receiver};

use crate::{alerts::{AlertEvent, AlertSeverity, alert_backend::AlertBackend}, config::Config, model::{cache::Cache, data::device::Device, db::operations::telegram_operations}, types::{AlertEventId, TelegramTypeId}};

// Emoji map as a function returning &'static str
fn emoji_map(severity: &AlertSeverity) -> &'static str {
    match severity {
        AlertSeverity::Emergency => "🆘🚨🚨",
        AlertSeverity::Alert     => "🚨🚨",
        AlertSeverity::Critical  => "🚨",
        AlertSeverity::Error     => "🚩",
        AlertSeverity::Warning   => "⚠️",
        AlertSeverity::Info      => "ℹ️",
        AlertSeverity::Notice    => "ℹ️",
        AlertSeverity::Debug     => "🕸️",
        AlertSeverity::Unknown   => "❔",
    }
}

fn format_alert(event: &AlertEvent, device: &Device, rule_name: &str) -> String {

    let tz : Tz = chrono_tz::Etc::GMTPlus6;

    let emoji = emoji_map(&event.severity);
    // let ack = if event.requires_ack { "Sí" } else { "No" };
    let time_str = match event.alert_time {
        Some(t) => t.with_timezone(&tz).format("%Y-%m-%d %H:%M:%S UTC%Z").to_string(),
        None=> "Desconocido".to_string()
    };

    format!(
        "```{emoji}¡Alerta!\n\
        🗓️ {time_str}\n\
        🖥️ {device_name}@{hostname}\
        \n\
        \n\
        {emoji} {:?}\n\n\
        {message}\n\n\n\
        Regla = {rule_name}\n\
        Evaluado={value}```",
        event.severity,
        device_name = device.device_name,
        hostname = device.management_hostname,
        message = event.message,
        rule_name = rule_name,
        value = event.value,
    )
}

pub struct TelegramBackend {
    client: Client,
    pool: sqlx::PgPool,

    subscribed_chats: RwLock<HashSet<TelegramTypeId>>
}
static INSTANCE: OnceLock<Arc<TelegramBackend>> = OnceLock::new();
impl TelegramBackend {
    // Internal constructor
    fn new(token: String, pool: sqlx::PgPool) -> Self {
        TelegramBackend { pool, client: Client::new(token).expect("[FATAL]Telegram Bot should be created correctly"), subscribed_chats: RwLock::new(HashSet::new())}
    }

    // Get singleton instance
    pub fn instance() -> Arc<TelegramBackend> {
        INSTANCE.get().expect("[FATAL]Telegram backend not initialized").clone()
    }

    // Get singleton instance
    pub fn try_instance() -> Option<Arc<TelegramBackend>> {
        INSTANCE.get().cloned()
    }

    // Initializes the telegram backend. Must be init after config is loaded
    pub async fn init(pool: sqlx::PgPool, alert_receiver: Receiver<AlertEvent>) {
        let enabled : bool = Config::instance().get("backend/controller/telegram/enabled", "/")
            .expect("[FATAL]Telegram enable status MUST be present in the config file at path 'backend/controller/telegram/enabled', an must be of type boolean");
        
        if !enabled {
            return;
        }

        let token: String = Config::instance().get("backend/controller/telegram/API-token", "/")
            .expect("[FATAL]Telegram API token MUST be present in the config file at path 'backend/controller/telegram/API-token', typically imported from identity via $ref");


        // Try to set instance Arc with provided value
        let backend = Arc::new(TelegramBackend::new(token, pool));
        let innit_bruv = INSTANCE.set(backend);

        if let Err(_) = innit_bruv {
            println!("[WARN][Telegram] Telegram backend was init more than once!. Ignoring second init...");
            return;
        }

        // Spawn dem tasks
        Self::spawn_telegram_poller_task();
        Self::spawn_telegram_alert_handler_task(alert_receiver);
        Self::update_user_cache().await;
    }

    async fn update_user_cache() {
        let instance = TelegramBackend::instance();
        let subscribed = telegram_operations::get_subscribed_users(&instance.pool).await;
        {
            let mut w = instance.subscribed_chats.write().await;
            w.clear();

            w.extend(subscribed.into_iter().map(|id| id as TelegramTypeId));
        }

        log::info!("[INFO ][ALERTS][TELEGRAM] Updated user cache")
    }

    fn spawn_telegram_poller_task() {
        rocket::tokio::spawn(async {
            let new_instance = TelegramBackend::instance();
            LongPoll::new(new_instance.client.clone(), Handler { client: new_instance.client.clone() }).run().await;
        });
    }

    fn spawn_telegram_alert_handler_task (mut alert_receiver: Receiver<AlertEvent>) {
        rocket::tokio::spawn(async move { loop {
            let event = match alert_receiver.recv().await {
                None=> continue,
                Some(monosodiumglutamate) => monosodiumglutamate
            };
            log::info!("[INFO ][ALERTS][TELEGRAM] Received an alert event");
            let instance = TelegramBackend::instance();
            let chats = instance.subscribed_chats.read().await;
            let client = &instance.client;
            let device = Cache::instance().get_device(event.target_id).await;
            let rule = AlertBackend::instance().get_rule_name(event.rule_id.unwrap_or(-1)).await.unwrap_or("[Regla eliminada]".to_string());

            let (device, rule) = match (device, rule) {
                (Some(device), rule) => (device, rule),
                (_, _) => {
                    log::error!("[ERROR][ALERTS][TELEGRAM] Failed to create rule string representation. Device or Rule invalid");
                    continue
                }
            };

            let msg = format_alert(&event, &device, &rule);

            for chat_id in chats.iter() {
                Handler::send_message(client, (*chat_id).into(), msg.as_str()).await;
            }
        }});
    }

    pub async fn raw_send_message(msg: &str) {
        let instance = TelegramBackend::instance();
        let chats = instance.subscribed_chats.read().await;
        let client = &instance.client;
        for chat_id in chats.iter() {
            Handler::send_message(client, (*chat_id).into(), msg).await;
        }
    }

}

struct Handler { client: Client }

#[derive(Serialize, Deserialize, Debug)]
struct TelegramAckActor {
    chat_id: ChatPeerId,
    alert_id: AlertEventId,
    acked: bool,
}

impl Handler {
    async fn send_message(client: &Client, chat_id: ChatPeerId, message: &str) {
        let message = message.replace(".", "\\.");
        let method = tgbot::types::SendMessage::new(chat_id, &message).with_parse_mode(ParseMode::MarkdownV2);
        match client.execute(method).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][ALERTS][TELEGRAM] failed to send message = '{}' with error = '{e}'. Message will be dropped", &message);
            }
        }
    }

    /* TODO: Readd if ack is reimlemented
    async fn send_message_button(client: &Client, chat_id: ChatPeerId, message: &str, alert_id: AlertEventId) {
        let message = message.replace(".", "\\.");
        use tgbot::types::*;
        let yes_btn = InlineKeyboardButton::for_callback_data_struct("Ack", &TelegramAckActor{ chat_id, alert_id: alert_id, acked: true}).unwrap();
        let no_btn = InlineKeyboardButton::for_callback_data_struct("Dismiss", &TelegramAckActor{ chat_id, alert_id: alert_id, acked: false}).unwrap();

        let keyboard = InlineKeyboardMarkup::default().add_row(vec![yes_btn, no_btn]);

        let method = SendMessage::new(chat_id, &message)
            .with_reply_markup(keyboard)
            .with_parse_mode(ParseMode::MarkdownV2);
        match client.execute(method).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][ALERTS][TELEGRAM] failed to send message = '{}' with error = '{e}'. Message will be dropped", &message);
            }
        }
    }*/

    pub async fn handle_start(client: &Client, chat_id: ChatPeerId) {
        let message : &'static str = "Comienza introduciendo el token de usuario con /auth [Token]";
        Handler::send_message(client, chat_id, message).await;
    }

    pub async fn handle_auth(client: &Client, chat_id: ChatPeerId, params: Option<&str>) {
        
        if let Ok(true) = telegram_operations::is_auth(chat_id, &TelegramBackend::instance().pool).await {
            Handler::send_message(client, chat_id, "Su chat ya había sido atenticado. No se requiere otra acción").await;
            return
        }

        // No token?
        let params = match params {
            Some(p) => p.trim_start().trim_end(),
            None => {
                Handler::send_message(client, chat_id, "No se ha proporcionado Token de autenticación. Intente nuevamente siguiendo el formato `/auth token`").await;
                return;
            }
        };

        // Invalid token?
        if let Err(_) = telegram_operations::ack_token_exists(params.to_string(), &TelegramBackend::instance().pool).await {
            Handler::send_message(client, chat_id, format!("El token introducido no es válido. Token introducido ='{}'", params).as_str()).await;
            return;
        }

        // Valid token, add the distinguished gentleman into the database
        match telegram_operations::auth_chat(chat_id, true, true, params.to_string(), &TelegramBackend::instance().pool).await {
            Ok(_) => {
                let msg = concat!(
                    "Autenticación exitosa ️✅\nSe ha suscrito automáticamente\n",
                    "verifica el estado de la autenticación con `chat_status` \n",
                    "o remueve la suscripción con `unsubscribe` sin deautenticar\n",
                );
                Handler::send_message(client, chat_id, msg).await;
            },
            Err(_) => {
                Handler::send_message(client, chat_id, "Error inesperado al realizar la autenticación. Intente nuevamente más tarde").await;
            }
        }

        TelegramBackend::update_user_cache().await;
    }

    pub async fn handle_subscribe(client: &Client, chat_id: ChatPeerId) {
        let instance = &TelegramBackend::instance().pool;
        let is_auth = match telegram_operations::is_auth(chat_id, instance).await {
            Ok(b) => b,
            Err(_) => {
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        };

        if !is_auth {
            Handler::send_message(client, chat_id, "Su chat NO está autenticado, utilice /auth Token").await;
            return;
        }

        match telegram_operations::subscribe_chat(chat_id, true, &TelegramBackend::instance().pool).await {
            Ok(_) => Handler::send_message(client, chat_id, "Está suscrito 👋\nRecibirá mensajes de alerta").await,
            Err(_) => Handler::send_message(client, chat_id, "Error inesperado al cambiar su estado de suscripción. Intente nuevamente más tarde").await
        }

        TelegramBackend::update_user_cache().await;
    }

    pub async fn handle_unsubscribe(client: &Client, chat_id: ChatPeerId) {
        let instance = &TelegramBackend::instance().pool;
        let _ = match telegram_operations::is_auth(chat_id, instance).await {
            Ok(b) => b,
            Err(_) => {
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        };

        match telegram_operations::subscribe_chat(chat_id, false, instance).await {
            Ok(_) => Handler::send_message(client, chat_id, "Ya no estás suscrito 👋").await,
            Err(_) => Handler::send_message(client, chat_id, "Error inesperado al cambiar su estado de suscripción. Intente nuevamente más tarde").await
        }

        TelegramBackend::update_user_cache().await;
    }

    pub async fn handle_chat_status(client: &Client, chat_id: ChatPeerId) {
        let instance = &TelegramBackend::instance().pool;
        let is_auth = telegram_operations::is_auth(chat_id, instance).await;
        let is_subd = telegram_operations::is_subscribed(chat_id, instance).await;

        let (is_auth, is_subd) = match (is_auth, is_subd){
            (Ok(b1), Ok(b2)) => (b1, b2),
            (_, _) => {
                Handler::send_message(client, chat_id, "Error inesperado al verificar su estado del chat. Intente nuevamente más tarde").await;
                return
            }
        };

        if is_auth {Handler::send_message(client, chat_id, "Su chat está autenticado ️✅").await; }
        else       {Handler::send_message(client, chat_id, "Su chat NO está autenticado ❌").await; }
        if is_subd {Handler::send_message(client, chat_id, "Su chat está suscrito ️✅").await; }
        else       {Handler::send_message(client, chat_id, "Su chat NO está suscrito ❌").await; }
    }
}

impl UpdateHandler for Handler {
    async fn handle(&self, update: tgbot::types::Update) {

        let chat_id = update.get_chat_id();
        match update.update_type {
            tgbot::types::UpdateType::Message(message) => {
                let text = message.get_text();
                let (chat_id, text) = match (chat_id, text) {
                    (Some(id), Some(text)) => (id, text),
                    (_, _) => return
                };

                let (command, args) = match text.data.split_once(" ") {
                    Some((cmd, args)) => (cmd, Some(args)),
                    None => (text.data.as_str(), None)
                };

                match command {
                    "/start"       => Handler::handle_start(&self.client, chat_id).await,
                    "/auth"        => Handler::handle_auth(&self.client, chat_id, args).await,
                    "/subscribe"   => Handler::handle_subscribe(&self.client, chat_id).await,
                    "/unsubscribe" => Handler::handle_unsubscribe(&self.client, chat_id).await,
                    "/chat_status" => Handler::handle_chat_status(&self.client, chat_id).await,
                    _ => {}
                }
            },
            tgbot::types::UpdateType::CallbackQuery(callback_query) => {
                let result : TelegramAckActor = match callback_query.parse_data() {
                    Ok(Some(a)) => a,
                    Ok(None) => return,
                    Err(_) => return,
                };

                dbg!(&result);
            },
            _ => {}
        }
    }
}