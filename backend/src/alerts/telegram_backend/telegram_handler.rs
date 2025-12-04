use std::result::Result::Ok;

use chrono::Utc;
use regex::Regex;
use sqlx::{Postgres, Transaction};
use tgbot::types::{AnswerCallbackQuery, CallbackQuery, EditMessageReplyMarkup, EditMessageText, InlineKeyboardMarkup, MaybeInaccessibleMessage, Message};
use tgbot::{api::Client, handler::UpdateHandler, types::{ChatPeerId, ParseMode, UserPeerId}};

use crate::alerts::telegram_backend::telegram_backend::TelegramBackend;
use crate::alerts::telegram_backend::{Handler, TelegramAckAction};
use crate::model::db::operations::{alert_operations, telegram_operations};
use crate::types::AlertEventId;

fn escape_with_backslash(s: &str, to_escape: &[char]) -> String {
    let set: std::collections::HashSet<char> = to_escape.iter().cloned().collect();

    s.chars()
        .flat_map(|c| {
            if set.contains(&c) {
                vec!['\\', c]
            } else {
                vec![c]
            }
        })
        .collect()
}

impl Handler {
    pub async fn send_message(client: &Client, chat_id: ChatPeerId, message: &str) {
        let message = message.replace(".", "\\.");
        let method = tgbot::types::SendMessage::new(chat_id, &message).with_parse_mode(ParseMode::MarkdownV2);
        match client.execute(method).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][ALERTS][TELEGRAM] failed to send message = '{}' with error = '{e}'. Message will be dropped", &message);
            }
        }
    }

    pub async fn send_message_button(client: &Client, chat_id: ChatPeerId, message: &str, alert_id: AlertEventId) {
        let message = message.replace(".", "\\.");
        use tgbot::types::*;
        let yes_btn = InlineKeyboardButton::for_callback_data_struct("Ack", &TelegramAckAction{ chat_id, alert_id: alert_id, acked: true}).unwrap();
        
        let keyboard = InlineKeyboardMarkup::default().add_row(vec![yes_btn]);

        let method = SendMessage::new(chat_id, &message)
            .with_reply_markup(keyboard)
            .with_parse_mode(ParseMode::MarkdownV2);
        match client.execute(method).await {
            Ok(_) => (),
            Err(e) => {
                log::error!("[ERROR][ALERTS][TELEGRAM] failed to send message = '{}' with error = '{e}'. Message will be dropped", &message);
            }
        }
    }

    pub async fn handle_start(client: &Client, chat_id: ChatPeerId) {
        let message : &'static str = "Comienza introduciendo el token de usuario con /auth [Token]";
        Handler::send_message(client, chat_id, message).await;
    }

    pub async fn handle_auth(client: &Client, chat_id: ChatPeerId, user_id: UserPeerId, is_private: bool, params: Option<&str>) {
        let pool_executor = &TelegramBackend::instance().pool;

        // 0.- Begin the transaction
        let mut transaction = match pool_executor.begin().await {
            Ok(t) => t,
            Err(e) => {
                Handler::send_message(client, chat_id, "Fallo en iniciar la transacción. Consulte con su administrador").await;
                log::error!("[ERROR][TELEGRAM] Failed to init auth transaction. SQL Error = '{}'", e);
                return;
            }
        };

        // 1.- Check if it's auth
        if let Ok(true) = telegram_operations::is_auth(chat_id, &pool_executor).await {
            Handler::send_message(client, chat_id, "Su chat ya había sido atenticado. No se requiere otra acción").await;
            return
        }

        // 2.- Check if the user provided a token
        let params = match params {
            Some(p) => p.trim_start().trim_end(),
            None => {
                Handler::send_message(client, chat_id, "No se ha proporcionado Token de autenticación. Intente nuevamente siguiendo el formato `/auth token`").await;
                return;
            }
        };

        // 3.- Check if the token exists in the database
        if let Err(_) = telegram_operations::ack_token_exists(params.to_string(), pool_executor).await {
            Handler::send_message(client, chat_id, format!("El token introducido no es válido. Token introducido =`{}`", params).as_str()).await;
            return;
        }

        // 4.- Add the chat to the auth'd list
        // Valid token, add the distinguished gentleman's chat into the database
        match telegram_operations::auth_chat(chat_id, true, true, params.to_string(), &mut transaction).await {
            Ok(_) => {},
            Err(_) => {
                Handler::send_message(client, chat_id, "Error inesperado al realizar la autenticación. Intente nuevamente más tarde").await;
                return; // early bail. rollback on the transaction
            }
        }

        // 5.- Match the telegram user to the token if it's a private chat, only if it hasn't been done before
        if is_private {

            let result = Self::_handle_auth_private(client, &chat_id, user_id, params.to_string(), &mut transaction, pool_executor).await;

            if let Err(_) = result {
                return
            }
        }

        // 6.- Commit transaction
        match transaction.commit().await {
            Ok(_) => {
                log::info!("[INFO][TELEGRAM][AUTH] Commit on database with updated values");
            },
            Err(e) => {
                Handler::send_message(client, chat_id, "Error inesperado al realizar la autenticación. Intente nuevamente más tarde").await;
                log::error!("[ERROR][TELEGRAM] Failed to commit auth transaction. SQL Error = '{e}'");
                return; // early bail. rollback on the transaction
            }
        }

        let msg = concat!(
            "Autenticación exitosa ️✅\nSe ha suscrito automáticamente\n",
            "verifica el estado de la autenticación con `chat_status` \n",
            "o remueve la suscripción con `unsubscribe` sin deautenticar\n",
        );
        Handler::send_message(client, chat_id, msg).await;

        TelegramBackend::update_user_cache().await;
    }

    pub async fn handle_subscribe(client: &Client, chat_id: ChatPeerId) {
        let instance = &TelegramBackend::instance().pool;
        // 0.- Begin transaction
        let mut transaction = match instance.begin().await {
            Ok(t) => t,
            Err(e) => {
                log::error!("[ERROR][TELEGRAM][DB] Failed to init transaction with SQL Error = '{e}'");
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        };

        // 1.- Check if the user is auth'd
        match telegram_operations::is_auth(chat_id, instance).await {
            Ok(true) => true,
            Ok(false) => {
                Handler::send_message(client, chat_id, "Su chat NO está autenticado, utilice /auth Token").await;
                return;
            }
            Err(_) => {
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        };

        // 2.- add the user's chat to the subscription list
        if let Err(_) = telegram_operations::subscribe_chat(chat_id, true, &mut transaction).await {
            Handler::send_message(client, chat_id, "Error inesperado al cambiar su estado de suscripción. Intente nuevamente más tarde").await
        }

        // 3.- Commit the transaction
        match transaction.commit().await {
            Ok(_) => {},
            Err(e) => {
                log::error!("[ERROR][TELEGRAM][DB] Failed to commit transaction with SQL Error = '{e}'");
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        }

        // notify the user
        Handler::send_message(client, chat_id, "Está suscrito 👋\nRecibirá mensajes de alerta").await;

        TelegramBackend::update_user_cache().await;
    }

    pub async fn handle_unsubscribe(client: &Client, chat_id: ChatPeerId) {
        let instance = &TelegramBackend::instance().pool;
        // 0.- Begin the transaction
        let mut transaction = match instance.begin().await {
            Ok(t) => t,
            Err(e) => {
                log::error!("[ERROR][TELEGRAM][DB] Failed to init transaction with SQL Error = '{e}'");
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        };

        // 1.- Check if it's auth'd, might be removable
        let _ = match telegram_operations::is_auth(chat_id, instance).await {
            Ok(b) => b,
            Err(_) => {
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        };

        // 2.- Remove the subscription status
        match telegram_operations::subscribe_chat(chat_id, false, &mut transaction).await {
            Ok(_) => {},
            Err(_) => Handler::send_message(client, chat_id, "Error inesperado al cambiar su estado de suscripción. Intente nuevamente más tarde").await
        }

        // 3.- Commit the transaction
        match transaction.commit().await {
            Ok(_) => {},
            Err(e) => {
                log::error!("[ERROR][TELEGRAM][DB] Failed to commit transaction with SQL Error = '{e}'");
                Handler::send_message(client, chat_id, "Error inesperado al recuperar el estado de autenticación. Intente nuevamente más tarde").await;
                return;
            }
        }

        // 4.- Notify the user
        Handler::send_message(client, chat_id, "Ya no estás suscrito 👋").await;

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

        let auth_status =
        if is_auth {"Su chat está autenticado ️✅"}
        else       {"Su chat NO está autenticado ❌"};

        let sub_status =
        if is_subd { "Su chat está suscrito ️✅" }
        else       { "Su chat NO está suscrito ❌" };

        Handler::send_message(client, chat_id, &format!("{}\n{}", auth_status, sub_status).to_string()).await;
    }

    async fn _handle_auth_private<'e>(client: &Client, chat_id: &ChatPeerId, user_id: UserPeerId, ack_token: String, transaction: &mut Transaction<'e, Postgres>, executor: &sqlx::Pool<Postgres>) -> Result<(), ()> {
        // 1.- Check if the user can be associated with the token
        // AKA: the token is not associated, or it's already been associated with THIS user
        let can_match = telegram_operations::can_match_user_with_token(user_id, &ack_token, executor).await;

        match can_match {
            // Can, let the user know
            Ok((true, name)) => {
                match telegram_operations::match_user_with_token(user_id, &ack_token, transaction).await {
                    Ok(_) => {
                        Handler::send_message(client, *chat_id, &format!("Token asociado a su usuario `{}` exitosamente", name)).await;
                    },
                    Err(_) => {
                        Handler::send_message(client, *chat_id, "Error: Error inesperado al asociar token-usuario. Intente nuevamente más tarde").await;
                        return Err(()); // early bail. rollback on the transaction
                    },
                }
            },
            // Can't, let the user know and leave without commit
            Ok((false, _)) => {
                Handler::send_message(client, *chat_id, "Error: Token ya asociado con otra cuenta. Consulte al administrador").await;
                return Err(()); // early bail. rollback on the transaction
            }
            // Some other error, let the user know and leave without commit
            Err(_) => {
                Handler::send_message(client, *chat_id,"Error: Error inesperado al realizar la verificación de la relación del token-usuario. Intente nuevamente más tarde").await;
                return Err(()); // early bail. rollback on the transaction
            }
        }

        Ok(())
    }
}

lazy_static::lazy_static! {
    // Unwrap: if this regex is for some reason invalid, it _must_ panic
    static ref BOT_TAG_RE: Regex = Regex::new(
        r"@.+?(\s|$)"
    ).unwrap();
}

async fn _handle_update_message(client: &Client, chat_id: Option<ChatPeerId>, user_id: Option<UserPeerId>, message: Message) {
    let text = message.get_text();
    let (chat_id, user_id, text) = match (chat_id, user_id, text) {
        (Some(id), Some(user_id), Some(text)) => (id, user_id, text),
        (_, _, _) => return
    };
    let text = BOT_TAG_RE.replace_all(&text.data, "$1");

    let (command, args) = match text.trim().split_once(" ") {
        Some((cmd, args)) => (cmd, Some(args)),
        None => (&(*text), None)
    };

    let is_private = match message.chat {
        tgbot::types::Chat::Private(_) => true,
        _ => false
    };

    match command {
        "/start"       => Handler::handle_start(client, chat_id).await,
        "/auth"        => Handler::handle_auth(client, chat_id, user_id, is_private, args).await,
        "/subscribe"   => Handler::handle_subscribe(client, chat_id).await,
        "/unsubscribe" => Handler::handle_unsubscribe(client, chat_id).await,
        "/chat_status" => Handler::handle_chat_status(client, chat_id).await,
        _ => {}
    }
}

async fn _handle_callback_query(client: &Client, callback_query: CallbackQuery) {
    // 1.- Extract the data
    let user = callback_query.from.id;
    let result : TelegramAckAction = match callback_query.parse_data() {
        Ok(Some(a)) => a,
        Ok(None) => return,
        Err(_) => return,
    };

    let instance = TelegramBackend::instance();

    // 2.- Begin the transaction
    let mut transaction = match instance.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("[ERROR][TELEGRAM] Failed to init transaction for alert ack, with SQL Error = '{e}'");
            return;
        } 
    };

    // 3.- Get the name of the ack actor as a string, not chat peer id
    let (ack_actor_name, can_ack) = match telegram_operations::get_user_name_from_peer_id(user, &mut transaction).await {
        Some(name) => name,
        None => {
            log::error!("[ERROR][TELEGRAM] Failed to get user name from telegram peer id. This user might not be authed!");
            return;
        }
    };

    // 4.- If the user can't ack, early bail
    if !can_ack {
        let notice = format!("Usuario `{}` No puede realizar ack", ack_actor_name);
        let method = AnswerCallbackQuery::new(&callback_query.id)
            .with_text(&notice)
            .with_show_alert(true);
        
        if let Err(e) = client.execute(method).await {
            log::error!("[ERROR][TELEGRAM] Failed to send AnswerCallbackResponse after ack! error = {e}");
        };
        return;
    }

    // 5.- Ack the alert in the database
    if let Err(_) = alert_operations::ack_alert(result.alert_id, &ack_actor_name, &mut transaction).await {
        log::error!("[ERROR][TELEGRAM] Failed to ack alert event! Rolling back...");
        return;
    }

    // 6.- Commit the transaction
    if let Err(e) = transaction.commit().await {
        log::error!("[ERROR][TELEGRAM] Failed to commit transaction during ack of alert. SQL Error = '{e}'");
        return
    }

    // 7.- Display floating button with the notice
    let notice = format!("Ack: `{}`\n\nHora: `{}`", ack_actor_name, Utc::now());
    let method = AnswerCallbackQuery::new(&callback_query.id)
        .with_text(&notice)
        .with_show_alert(true);
    if let Err(e) = client.execute(method).await {
        log::error!("[ERROR][TELEGRAM] Failed to send AnswerCallbackResponse after ack! error = {e}");
        return;
    };

    // 8.- Update the message reply
    if let Some(MaybeInaccessibleMessage::Message(m)) = callback_query.message {
        let keyboard = InlineKeyboardMarkup::default().add_row([]);
        let method = EditMessageReplyMarkup::for_chat_message(result.chat_id, m.id)
            .with_reply_markup(keyboard);

        if let Err(e) = client.execute(method).await {
            log::error!("[ERROR][TELEGRAM] Failed to update message reply inline Keyboard after ack! error = {e}");
            return;
        };
        
        let text = match m.get_text() {
            Some(t) => &t.data,
            None => {
                log::error!("[ERROR][TELEGRAM] Failed to get text from message for update during ack");
                return;
            }
        };
        let text = format!("```Acked\n{}```\n{}", text, escape_with_backslash(&notice, &['.', '-']));
        let method = EditMessageText
            ::for_chat_message(result.chat_id, m.id, text)
            .with_parse_mode(ParseMode::MarkdownV2);
        if let Err(e) = client.execute(method).await {
            log::error!("[ERROR][TELEGRAM] Failed to update message contents after ack! error = {e}");
            return;
        };

    } else {
        log::warn!("[WARN ][TELEGRAM] Ack'd for unavailable message. This is rare");
        return;
    };
}

impl UpdateHandler for Handler {
    async fn handle(&self, update: tgbot::types::Update) {
        let chat_id = update.get_chat_id();
        let user_id = update.get_user_id();
        match update.update_type {
            tgbot::types::UpdateType::Message(message) => {
                _handle_update_message(&self.client, chat_id, user_id, message).await;
            },
            tgbot::types::UpdateType::CallbackQuery(callback_query) => {
                _handle_callback_query(&self.client, callback_query).await;
            },
            _ => {}
        }
    }
}