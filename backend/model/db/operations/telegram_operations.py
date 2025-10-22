
from typing import List

from model.db.pools import postgres_db_pool


def get_subscribed_users() -> List[int]:
    try:
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT telegram_user_id FROM Analytics.telegram_receiver WHERE authenticated AND subscribed", ())

                return list(cur.fetchall())

    except Exception as e:
        print("[ERROR][TELEGRAM][DB]Failed to get auth'd users with error=",str(e))
        return []


def auth_chat(chat_id: int, auth: bool, subscribed: bool) -> bool:
    try:
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO Analytics.telegram_receiver(telegram_user_id, authenticated, subscribed) 
                    VALUES (%s, %s, %s)
                    ON CONFLICT(telegram_user_id) 
                        DO UPDATE SET authenticated = %s, subscribed = %s WHERE Analytics.telegram_receiver.telegram_user_id = %s;
                """, (chat_id, auth, subscribed, auth, subscribed, chat_id))

        return True

    except Exception as e:
        print("[ERROR][TELEGRAM][DB]Failed to insert auth'd user with error=", str(e))
        return False


def is_auth(chat_id: int) -> bool | None:
    value = None
    try:
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute ("SELECT authenticated FROM Analytics.telegram_receiver WHERE telegram_user_id = %s", (chat_id,))

                value = cur.fetchone()

                if value is None:
                    return False
                return value[0]

    except Exception as e:
        print("[ERROR][TELEGRAM][DB]Failed to check auth status with error=", str(e))
        value = None

    return value


def is_subscribed(chat_id: int) -> bool | None:
    value = None
    try:
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute ("SELECT subscribed FROM Analytics.telegram_receiver WHERE telegram_user_id = %s", (chat_id,))

                value = cur.fetchone()

                if value is None:
                    return False
                return value[0]

    except Exception as e:
        print("[ERROR][TELEGRAM][DB]Failed to check subscribe status with error=", str(e))
        value = None

    return value
