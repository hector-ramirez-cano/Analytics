import asyncio

import psycopg_pool

from model.db.pools import postgres_db_pool, influx_db_client

health_check_listeners = []


def check_postgres_connection(conn):
    try:
        psycopg_pool.ConnectionPool.check_connection(conn)

    except Exception as e:
        asyncio.create_task(notify_health_listeners(postgres_status={"up": False, "msg": str(e)}))
        raise


async def notify_health_listeners(postgres_status : dict | None = None, influx_status: dict | None = None, full_status: dict | None = None):
    if (postgres_status == influx_status == full_status is None) or len(health_check_listeners) == 0:
        return

    status = { "status" : {}}
    if full_status is not None:
        status = full_status

    if postgres_status is not None:
        status["status"]["postgres"] = postgres_status

    if influx_status is not None:
        status["status"]["influx"] = influx_status

    for queue in health_check_listeners:
        await queue.put(status)


async def periodic_health_check(stop_event : asyncio.Event):
    while not stop_event.is_set():

        try:
            # timeout
            await asyncio.wait_for(stop_event.wait(), 15)

        except asyncio.TimeoutError:
            # manual check
            await notify_health_listeners(full_status=check_connections())

        except Exception as e:
            print(f"[ERROR][FACTS]registered exception e='{str(e)}'")


def check_connections() -> dict:
    postgres_status = {"up": False, "msg": ""}
    influx_status   = {"up": False, "msg": ""}

    # Postgres health check
    try:
        postgres_db_pool().check()
        with postgres_db_pool().connection(timeout=3) as conn:
            row = conn.execute("SELECT 1") # TODO: Perhaps remove it, as acquiring the conn means health check passed
            postgres_status["up"] = True
    except psycopg_pool.PoolTimeout as e:
        postgres_status["up"] = False
        postgres_status["msg"] = str(e)

    # InfluxDB HealthCheck
    influx_status["up"] = influx_db_client().ping()


    return {"status" : {"postgres" : postgres_status, "influx": influx_status} }


