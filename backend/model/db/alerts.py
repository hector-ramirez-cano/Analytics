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