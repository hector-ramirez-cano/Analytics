use serde::{Deserialize, Serialize};
use tgbot::{api::Client, types::ChatPeerId};

use crate::types::AlertEventId;

pub mod backend;

struct Handler { client: Client }

#[derive(Serialize, Deserialize, Debug)]
struct TelegramAckAction {
    chat_id: ChatPeerId,
    alert_id: AlertEventId,
    acked: bool,
}


mod telegram_handler;