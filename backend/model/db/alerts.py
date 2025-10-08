from backend.model.alerts.alert_event import AlertEvent
from backend.model.db.pools import postgres_db_pool

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
    try:
        with postgres_db_pool().connection() as conn, conn.cursor() as cur:
            cur.execute(
                """
                    INSERT INTO Analytics.alerts(alert_time, requires_ack, severity, message, target_id) VALUES (%s, %s , %s , %s, %s)
                """,
                (alert.alert_time, alert.requires_ack, alert.severity.value, alert.message, alert.target_id)
            )

        return True

    except Exception as e:
        print(f"[ERROR][DB]Failed to insert Alert with error='{str(e)}'")
        return False