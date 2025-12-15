use std::{collections::HashSet, sync::{Arc, OnceLock}};

use chrono_tz::Tz;
use rocket::futures::future::join_all;
use tgbot::{api::Client, handler::LongPoll, types::ChatPeerId};
use tokio::sync::{RwLock, mpsc::Receiver};

use crate::{alerts::telegram_backend::Handler, model::db::operations::telegram_operations};
use crate::{alerts::{AlertEvent, AlertSeverity, alert_backend::AlertBackend}, config::Config, model::{cache::Cache, data::device::Device}, types::TelegramTypeId};

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
        🖥️ {device_name}@{hostname}\n\
        Requiere ACK: {requires_ack}\
        \n\
        \n\
        \n\
        {emoji} {:?}\n\n\
        {message}\n\n\n\
        Regla = {rule_name}\n\
        Evaluado={value}```",
        event.severity,
        requires_ack = event.requires_ack,
        device_name = device.device_name,
        hostname = device.management_hostname,
        message = event.message,
        rule_name = rule_name,
        value = event.value,
    )
}

pub struct TelegramBackend {
    client: Client,
    pub pool: sqlx::PgPool,

    subscribed_chats: RwLock<HashSet<TelegramTypeId>>
}
static INSTANCE: OnceLock<Arc<TelegramBackend>> = OnceLock::new();
impl TelegramBackend {
    /// Internal constructor
    fn new(token: String, pool: sqlx::PgPool) -> Self {
        TelegramBackend { pool, client: Client::new(token).expect("[FATAL]Telegram Bot should be created correctly"), subscribed_chats: RwLock::new(HashSet::new())}
    }

    /// Get singleton instance
    pub fn instance() -> Arc<TelegramBackend> {
        INSTANCE.get().expect("[FATAL]Telegram backend not initialized").clone()
    }

    /// Get singleton instance
    pub fn try_instance() -> Option<Arc<TelegramBackend>> {
        INSTANCE.get().cloned()
    }

    /// Initializes the telegram backend. Must be init after config is loaded
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

        if innit_bruv.is_err() {
            println!("[WARN][Telegram] Telegram backend was init more than once!. Ignoring second init...");
            return;
        }

        // Spawn dem tasks
        Self::spawn_telegram_poller_task();
        Self::spawn_telegram_alert_handler_task(alert_receiver);
        Self::update_user_cache().await;
    }

    pub async fn update_user_cache() {
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
        rocket::tokio::spawn(async move { 
            loop {
                let event = match alert_receiver.recv().await {
                    None=> continue,
                    Some(monosodiumglutamate) => monosodiumglutamate
                };

                let instance = TelegramBackend::instance();
                let pool_executor = &instance.pool;
                log::info!("[INFO ][ALERTS][TELEGRAM] Received an alert event");

                // 0.- Update the user cache and rule mapping to only send to auth'd users, and look up devices
                TelegramBackend::update_user_cache().await;
                let chats = instance.subscribed_chats.read().await;
                let client = &instance.client;
                let device = Cache::instance().get_device(event.target_id).await;
                let rule = AlertBackend::instance().get_rule_name(event.rule_id.unwrap_or(-1)).await.unwrap_or("[Regla eliminada]".to_string());

                // 1.- Make a string representation of the alert event's rule
                let (device, rule) = match (device, rule) {
                    (Some(device), rule) => (device, rule),
                    (_, _) => {
                        log::error!("[ERROR][ALERTS][TELEGRAM] Failed to create rule string representation. Device or Rule invalid");
                        continue
                    }
                };

                let msg = format_alert(&event, &device, &rule);

                // 2.- Update the Telegram listeners, and store their messages
                if !event.requires_ack {
                    for chat_id in chats.iter() {
                        Handler::send_message(client, (*chat_id).into(), msg.as_str()).await;
                    } 
                    return;
                } 
                let futures = chats.iter().map(|chat_id| {
                    Handler::send_message_button(
                        client,
                        (*chat_id).into(),
                        msg.as_str(),
                        event.alert_id,
                    )
                });
                let msgs: Vec<(ChatPeerId, i64)> = join_all(futures).await.into_iter().filter_map(|f| f.ok()).collect();
                if msgs.is_empty() { return; }

                // 3.- Begin the transaction to store the Telegram messages as pending from Ack, so they can be later on updated
                let mut transaction = match pool_executor.begin().await {
                    Ok(t) => t,
                    Err(e) => {
                        log::error!("[ERROR][TELEGRAM] Failed to init ack message SQL transaction. SQL Error = '{}'", e);
                        return;
                    }
                };

                // 4.- Store the messages into the database
                for msg in msgs {
                    match telegram_operations::insert_unacked_message(event.alert_id, msg.0, msg.1, &mut transaction).await {
                        Ok(_) => (),
                        Err(e) => {
                            log::error!("[ERROR][TELEGRAM] Failed to store message for future ack'ing. SQL Error = '{e}'")
                        },
                    }
                }

                if let Err(e) = transaction.commit().await {
                    log::error!("[ERROR][TELEGRAM] Failed to commit transaction during ack of alert. SQL Error = '{e}'");
                    return
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

