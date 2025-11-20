use sqlx::FromRow;
use tgbot::types::ChatPeerId;


#[derive(FromRow)]
struct TelegramUser {
    telegram_user_id: i64
}

pub async fn get_subscribed_users(pool: &sqlx::PgPool) -> Vec<i64> {
    let items = sqlx::query_as!(TelegramUser, "SELECT telegram_user_id FROM ClientIdentity.telegram_receiver WHERE authenticated AND subscribed;").fetch_all(pool).await;

    let items = match items {
        Ok(i) => i,
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM] Failed to query subscribed users from database with error = e '{e}'. Alert events that depend on this will not be sent");
            return Vec::new()
        }
    };

    items.iter().map(|i| i.telegram_user_id).collect()
}

pub async fn auth_chat(chat: ChatPeerId, auth: bool, subscribed: bool, ack_token: String, pool: &sqlx::PgPool) -> Result<(), ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query!("
        INSERT INTO ClientIdentity.telegram_receiver(telegram_user_id, authenticated, subscribed, ack_token) 
        VALUES ($1, $2, $3, $4)
        ON CONFLICT(telegram_user_id) 
            DO UPDATE SET authenticated = $5, subscribed = $6, ack_token = $7 WHERE ClientIdentity.telegram_receiver.telegram_user_id = $8;
    ", id, auth, subscribed, ack_token, auth, subscribed, ack_token, id).execute(pool).await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to update user request to create/update auth status into database, with error = '{e}'");
            Err(())
        }
    }
}

pub async fn subscribe_chat(chat: ChatPeerId, subscribed: bool, pool: &sqlx::PgPool) -> Result<(), ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query!("
        UPDATE ClientIdentity.telegram_receiver SET subscribed = $1 WHERE ClientIdentity.telegram_receiver.telegram_user_id = $2 AND authenticated = TRUE;
    ", subscribed, id).execute(pool).await;

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
            SELECT 1 FROM ClientIdentity.telegram_receiver WHERE telegram_user_id = $1 AND authenticated is TRUE LIMIT 1
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
            SELECT 1 FROM ClientIdentity.telegram_receiver WHERE telegram_user_id = $1 AND subscribed is TRUE LIMIT 1
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