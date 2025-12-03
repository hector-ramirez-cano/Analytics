use sqlx::{FromRow, Postgres, Transaction};
use tgbot::types::{ChatPeerId, UserPeerId};

use crate::types::TelegramTypeId;


#[derive(FromRow)]
pub struct TelegramChat {
    telegram_chat_id: TelegramTypeId
}

pub async fn get_subscribed_users(pool: &sqlx::PgPool) -> Vec<TelegramTypeId> {
    let items = sqlx::query_as!(TelegramChat,
        "SELECT telegram_chat_id FROM ClientIdentity.telegram_receiver WHERE authenticated AND subscribed;")
        .fetch_all(pool).await;

    let items = match items {
        Ok(i) => i,
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM] Failed to query subscribed users from database with error = e '{e}'. Alert events that depend on this will not be sent");
            return Vec::new()
        }
    };

    items.iter().map(|i| i.telegram_chat_id).collect()
}

pub async fn auth_chat<'e>(chat: ChatPeerId, auth: bool, subscribed: bool, ack_token: String, transaction: &mut Transaction<'e, Postgres>) -> Result<(), ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query!("
        INSERT INTO ClientIdentity.telegram_receiver(telegram_chat_id, authenticated, subscribed, ack_token)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT(telegram_chat_id)
            DO UPDATE SET authenticated = $5, subscribed = $6, ack_token = $7 WHERE ClientIdentity.telegram_receiver.telegram_chat_id = $8;
    ", id, auth, subscribed, ack_token, auth, subscribed, ack_token, id).execute(&mut **transaction).await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to update user request to create/update auth status into database, with error = '{e}'");
            Err(())
        }
    }
}

pub async fn get_user_name_from_peer_id<'e>(user: UserPeerId, transaction: &mut Transaction<'e, Postgres>) -> Option<(String, bool)> {
    let id : i64 = user.into();

    #[derive(FromRow)]
    struct LocalName { ack_actor_name: String, can_ack: bool }

    let result : Result<LocalName, sqlx::Error> = sqlx::query_as!(LocalName, "
        SELECT ack_actor_name, can_ack FROM ClientIdentity.ack_tokens WHERE telegram_user_id = $1;",
        id
    ).fetch_one(&mut **transaction).await;

    match result {
        Ok(id) => {
            Some((id.ack_actor_name, id.can_ack))
        },
        Err(e) => {
            log::error!("[ERROR][TELEGRAM][DB] Failed to query user telegram association from db with SQL error = {e}");
            None
        }
    }
}

pub async fn can_match_user_with_token(user: UserPeerId, ack_token: &str, pool: &sqlx::PgPool) -> Result<(bool, String), ()> {
    let id : i64 = user.into();

    #[derive(FromRow)]
    struct LocalId { valid: Option<bool>, ack_actor_name: String }

    let result : Result<LocalId, sqlx::Error> = sqlx::query_as!(LocalId, "
        SELECT (telegram_user_id IS NULL OR telegram_user_id = $1) as valid, ack_actor_name FROM ClientIdentity.ack_tokens WHERE ack_token = $2;",
        id, ack_token
    ).fetch_one(pool).await;

    match result {
        Ok(id) => {
            match id.valid {
                Some(valid) => Ok((valid, id.ack_actor_name)),
                None => Ok((false, String::new()))
            } 
        },
        Err(e) => {
            log::error!("[ERROR][TELEGRAM][DB] Failed to query user token association from db with SQL error = {e}");
            Err(())
        }
    }
}


pub async fn match_user_with_token<'e>(user: UserPeerId, ack_token: &str, transaction: &mut Transaction<'e, Postgres>) -> Result<(), ()> {
    let id : i64 = user.into();

    let result = sqlx::query!("
        UPDATE ClientIdentity.ack_tokens SET telegram_user_id = $1 WHERE ack_token = $2",
        id , ack_token
    ).execute(&mut **transaction).await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to update user request to create/update auth status into database, with error = '{e}'");
            Err(())
        }
    }
}

pub async fn subscribe_chat<'e>(chat: ChatPeerId, subscribed: bool, transaction: &mut Transaction<'e, Postgres>) -> Result<(), ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query!("
        UPDATE ClientIdentity.telegram_receiver SET subscribed = $1 WHERE ClientIdentity.telegram_receiver.telegram_chat_id = $2 AND authenticated = TRUE;
    ", subscribed, id).execute(&mut **transaction).await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to update user request to create/update auth status into database, with error = '{e}'");
            Err(())
        }
    }
}

pub async fn ack_token_exists(ack_token: String, pool: &sqlx::PgPool) -> Result<(), ()> {

    let result = sqlx::query!("
        SELECT (1) as found FROM ClientIdentity.ack_tokens WHERE ack_token = $1"
    , ack_token).fetch_one(pool).await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to update user request to create/update auth status into database, with error = '{e}'");
            Err(())
        }
    }
}

#[derive(FromRow)]
struct ChatAuth {
    authenticated: Option<bool>,
}
pub async fn is_auth(chat: ChatPeerId, pool: &sqlx::PgPool) -> Result<bool, ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query_as!( ChatAuth,"
        SELECT EXISTS(
            SELECT 1 FROM ClientIdentity.telegram_receiver WHERE telegram_chat_id = $1 AND authenticated is TRUE LIMIT 1
        ) as authenticated
        ", id
    ).fetch_one(pool).await;

    match result {
        Ok(result) => Ok(result.authenticated.unwrap_or(false)),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to request auth state for user from database, with error = '{e}'");
            Err(())
        }
    }
}

pub async fn is_subscribed(chat: ChatPeerId, pool: &sqlx::PgPool) -> Result<bool, ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query_as!( ChatAuth,"
        SELECT EXISTS(
            SELECT 1 FROM ClientIdentity.telegram_receiver WHERE telegram_chat_id = $1 AND subscribed is TRUE LIMIT 1
        ) as authenticated
        ", id
    ).fetch_one(pool).await;

    match result {
        Ok(result) => Ok(result.authenticated.unwrap_or(false)),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to request subscription state for user from database, with error = '{e}'");
            Err(())
        }
    }
}