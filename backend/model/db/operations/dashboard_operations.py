from model.db.pools import postgres_db_pool

def get_dashboards_as_dict() -> dict:
    dashboards = {}

    with postgres_db_pool().connection() as conn, conn.cursor() as cur:
        cur.execute(
            """
                SELECT * FROM Analytics.dashboard
            """
        )

        for row in cur.fetchall():
            dashboards[row[0]] = {"name": row[1], "widgets": []}

        cur.execute(
            """
                SELECT * FROM Analytics.dashboard_items
            """
        )

        for row in cur.fetchall():
            dashboard = dashboards.get(row[0], None)

            if dashboard is None:
                continue

            widget = {"row": row[1], "row-span": row[2], "col": row[3], "col-span": row[4]}
            widget["polling-definition"] = row[5]

            dashboards[row[0]]["widgets"].append(widget)

    return dashboards
