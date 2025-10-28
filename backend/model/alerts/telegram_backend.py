import asyncio

from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes
from telegram.error import BadRequest

from model.alerts.alert_backend import AlertBackend
from model.alerts.alert_event import AlertEvent
from model.alerts.alert_severity import AlertSeverity
from model.alerts.alert_rules import AlertRule
from model.cache import Cache
from model.db.operations.telegram_operations import auth_chat, is_auth, is_subscribed, get_subscribed_users
from controller.sentinel import Sentinel
from Config import Config

#POST https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setMyCommands
#Content-Type: application/json

COMMANDS = {
    "commands": [
        { "command": "start"      , "description": "Start the bot" },
        { "command": "auth"       , "description": "Autentica a este usuario para recibir actualizaciones" },
        { "command": "subscribe"  , "description": "Suscribe este usuario a recibir actualizaciones" },
        { "command": "chat_status", "description": "Devuelve el estado de autenticación y suscripción de este usuario" },
        { "command": "unsubscribe", "description": "Remueve la suscripción de este usuario y elimina su registro de autenticación" },
    ]
}

async def __start(update: Update, _: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Comienza introduciendo el token de usuario con /auth [Token]")


async def __auth(update: Update, _: ContextTypes.DEFAULT_TYPE):
    full_text = update.message.text

    # Removin' everything after /auth
    args = full_text.removeprefix("/auth").removeprefix(" ")

    if not Config.has(path="backend/controller/telegram/User-token"):
        print("[ERROR][TELEGRAM]Archivo de configuración no definió un token de usuario válido para el bot de Telegram")
        await update.message.reply_text("[ERROR]Verifique su configuración de backend")
        return

    if len(args) == 0:
        await update.message.reply_text("No se ha provisto token, utiliza /auth [Token]")
        return

    if args != Config.get("backend/controller/telegram/User-token", ):
        await update.message.reply_text("El token provisto no es válido")
        return

    # add this chat to the database
    chat_id = update.effective_chat.id
    auth = True
    if auth_chat(chat_id, auth, True):
        await update.message.reply_text("Autenticación exitosa ️✅\nSe ha suscrito automáticamente")
        await update.message.reply_text("verifica el estado de la autenticación con /chat_status")
        await update.message.reply_text("o remueve la suscripción con /unsubscribe sin deautenticar")
    else:
        msg = "Autenticación falló, intente nuevamente más tarde"
        await update.message.reply_text(msg)


async def __unsuscribe(update: Update, _: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    auth = is_auth(chat_id)
    if auth_chat(chat_id, auth, False):
        await update.message.reply_text("Ya no estás suscrito 👋")
        await update.message.reply_text("Puedes volver realizar la suscripción con /subscribe o /auth")
    else:
        msg = "Autenticación falló, intente nuevamente más tarde"
        await update.message.reply_text(msg)

async def __suscribe(update: Update, _: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id

    if not is_auth(chat_id):
        await update.message.reply_text("Su chat NO está autenticado, utilice /auth [Token]")
        return

    if auth_chat(chat_id, is_auth(chat_id), True):
        await update.message.reply_text("Está suscrito 👋\nRecibirá mensajes de alerta")
    else:
        await update.message.reply_text("Ocurrió un error, intente de nuevo más tarde")


async def __chat_status(update: Update, _: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    auth_status = is_auth(chat_id)
    subscribe_status = is_subscribed(chat_id)
    if auth_status is None or subscribe_status is None:
        await update.message.reply_text("Ocurrió un error, intente nuevamente más tarde")

    elif auth_status:
        await update.message.reply_text("Su chat está autenticado ️✅")
    else:
        await update.message.reply_text("Su chat NO está autenticado ❌")

    if subscribe_status:
        await update.message.reply_text("Su chat está suscrito ️✅")
    else:
        await update.message.reply_text("Su chat NO está suscrito ❌")

app = ApplicationBuilder().token(Config.get("backend/controller/telegram/API-token")).build()
async def init(stop_event: asyncio.Event):
    """Inits the command handlers for the telegram bot and attaches to listen to alerts

    Args:
        stop_event (asyncio.Event): Notifies the bot to exit
    """
    global app
    is_init = False

    while not is_init:
        try:
            app = ApplicationBuilder().token(Config.get("backend/controller/telegram/API-token")).build()
            await app.initialize()
            await app.start()
            await app.updater.start_polling()
            is_init = True

        except TimeoutError as e:
            print(f"[ERROR]Telegram bot api timed out during initialization with e={str(e)}. Retrying...")

    app.add_handler(CommandHandler("start", __start))
    app.add_handler(CommandHandler("auth", __auth))
    app.add_handler(CommandHandler("subscribe", __suscribe))
    app.add_handler(CommandHandler("unsubscribe", __unsuscribe))
    app.add_handler(CommandHandler("chat_status", __chat_status))

    # attach to listen
    queue = asyncio.Queue()
    alert_handler = handle_alerts(queue, stop_event)

    await alert_handler
    await stop_event.wait()
    await queue.put(Sentinel())

emojiMap = {
    AlertSeverity.EMERGENCY: "🆘🚨🚨",
    AlertSeverity.ALERT    : "🚨🚨",
    AlertSeverity.CRITICAL : "🚨",
    AlertSeverity.ERROR    : "🚩",
    AlertSeverity.WARNING  : "⚠️",
    AlertSeverity.NOTICE   : "ℹ️",
    AlertSeverity.DEBUG    : "🕸️",
    AlertSeverity.UNKNOWN  : "❔"
}

def format_alert(event: AlertEvent) -> str:
    device = Cache().get_item(event.target_id)
    rule : AlertRule = AlertBackend().rules[event.rule_id]

    message = (
        f"```{emojiMap[event.severity]}¡Alerta!\n"
        f"📌 Requiere Ack: {'Sí' if event.requires_ack else 'No'}\n"
        f"{event.alert_time.strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"🖥️ : {device.device_name}@{device.management_hostname}\n\n"
        f"{emojiMap[event.severity]} {event.severity}\n"
        f"{event.message}\n\n"
        f"Regla = {rule.name}\n"
        f"Evaluado={event.value}```"
    )

    return message


async def handle_alerts(queue: asyncio.Queue[AlertEvent], stop_event : asyncio.Event):
    AlertBackend.register_listener(queue)
    while not stop_event.is_set():
        try:
            msg = await queue.get()

            if msg == Sentinel():
                break

            # get list of users that asked to be notified
            chats = get_subscribed_users()

            try:
                msg = format_alert(msg)
                for chat in chats:
                    await app.bot.send_message(chat_id=int(chat[0]), text=msg, parse_mode="MarkdownV2")
            except BadRequest:
                # a chat was supplied, that no longer exists
                pass

        except Exception as e:
            print("[ERROR][Telegram][Alerts]Failed to get alert from queue with error=", str(e))
