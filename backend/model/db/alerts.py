from model.alerts.alert_event import AlertEvent
from model.db.pools import postgres_db_pool

def update_alert_config() -> list[tuple]:
    with postgres_db_pool().connection() as conn, conn.cursor() as cur:
        cur.execute(
            """
                SELECT * FROM Analytics.alert_rules
            """
        )

        rules = []

        for row in cur.fetchall():
            rule_id = row[0]
            name = row[1]
            requires_ack = row[2]
            definition = row[3]
            rules.append((rule_id, name, requires_ack, definition))

        return rules


def insert_alert(alert: AlertEvent) -> bool:
    """
    Updates the database with a new alert event, as received by the worker thread.
    :param alert event
    """
    try:
        with postgres_db_pool().connection() as conn, conn.cursor() as cur:
            cur.execute(
                """
                    INSERT INTO Analytics.alerts(alert_time, requires_ack, severity, message, target_id) 
                    VALUES (%s, %s , %s , %s, %s)
                    RETURNING alert_id;
                """,
                (alert.alert_time, alert.requires_ack, alert.severity.value, alert.message, alert.target_id)
            )

            alert.alert_id = cur.fetchone()[0]

        return True

    except Exception as e:
        print(f"[ERROR][DB]Failed to insert Alert with error='{str(e)}'")
        return False

def get_rules_as_list() -> list[dict]:
    rules = update_alert_config()

    arr = []

    for rule in rules:
        arr.append({
            "rule-id": rule[0],
            "name": rule[1],
            "requires-ack": rule[2],
            "definition": rule[3]
        })

    return arr
