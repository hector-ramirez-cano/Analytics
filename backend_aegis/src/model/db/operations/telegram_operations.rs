use sqlx::FromRow;
use tgbot::types::ChatPeerId;


#[derive(FromRow)]
struct TelegramUser {
    telegram_user_id: i64
}

pub async fn get_subscribed_users(pool: &sqlx::PgPool) -> Vec<i64> {
    let items = sqlx::query_as!(TelegramUser, "SELECT telegram_user_id FROM Analytics.telegram_receiver WHERE authenticated AND subscribed;").fetch_all(pool).await;

    let items = match items {
        Ok(i) => i,
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM] Failed to query subscribed users from database with error = e '{e}'. Alert events that depend on this will not be sent");
            return Vec::new()
        }
    };

    items.iter().map(|i| i.telegram_user_id).collect()
}

pub async fn auth_chat(chat: ChatPeerId, auth: bool, subscribed: bool, pool: &sqlx::PgPool) -> Result<(), ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query!("
        INSERT INTO Analytics.telegram_receiver(telegram_user_id, authenticated, subscribed) 
        VALUES ($1, $2, $3)
        ON CONFLICT(telegram_user_id) 
            DO UPDATE SET authenticated = $4, subscribed = $5 WHERE Analytics.telegram_receiver.telegram_user_id = $6;
    ", id, auth, subscribed, auth, subscribed, id).execute(pool).await;

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
    authenticated: bool,
}
pub async fn is_auth(chat: ChatPeerId, pool: &sqlx::PgPool) -> Result<bool, ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query_as!( ChatAuth,
        "SELECT authenticated FROM Analytics.telegram_receiver WHERE telegram_user_id = $1", id
    ).fetch_one(pool).await;

    match result {
        Ok(result) => Ok(result.authenticated),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to request auth state for user from database, with error = '{e}'");
            Err(())
        }
    }
}

pub async fn is_subscribed(chat: ChatPeerId, pool: &sqlx::PgPool) -> Result<bool, ()> {
    let id : i64 = serde_json::json!(chat).as_i64().ok_or(())?;
    let result = sqlx::query_as!( ChatAuth,
        "SELECT subscribed as authenticated FROM Analytics.telegram_receiver WHERE telegram_user_id = $1", id
    ).fetch_one(pool).await;

    match result {
        Ok(result) => Ok(result.authenticated),
        Err(e) => {
            log::error!("[ERROR][ALERTS][TELEGRAM][DB] Failed to request subscription state for user from database, with error = '{e}'");
            Err(())
        }
    }
}