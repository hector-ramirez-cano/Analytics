from typing import Optional

from influxdb_client import WriteApi, InfluxDBClient
from influxdb_client.client.write_api import SYNCHRONOUS
from psycopg_pool import ConnectionPool

import Config

# TODO: Check when DB handle is no longer valid
_postgres_db_pool: Optional[ConnectionPool] = None
_influx_db_client: Optional[InfluxDBClient] = None
_influx_db_write_api : Optional[WriteApi]   = None

def init_db_pool(check_postgres_connection):
    global _postgres_db_pool, _influx_db_write_api, _influx_db_client

    if _postgres_db_pool is not None:
        return


    # TODO: Remove access to password
    port = Config.Config.get("backend/controller/postgres/port", 5432)
    host = Config.Config.get("backend/controller/postgres/hostname")
    dbname = Config.Config.get("backend/controller/postgres/name")
    user = Config.Config.get("backend/controller/postgres/user")
    password = Config.Config.get("backend/controller/postgres/password")
    schema = Config.Config.get("backend/controller/postgres/schema", "postgresql://")
    conn_uri = schema + user + ":" + password + "@" + host + ":" + str(port) + "/" + dbname
    _postgres_db_pool = ConnectionPool(
        conninfo=conn_uri,
        max_idle=Config.Config.get("backend/controller/postgres/max_idle_s", 60),
        num_workers=Config.Config.get("backend/controller/postgres/num_workers", 3),
        min_size=Config.Config.get("backend/controller/postgres/min_size", 1),
        max_size=Config.Config.get("backend/controller/postgres/max_size", 10),
        reconnect_timeout=Config.Config.get("backend/controller/postgres/reconnect_timeout_s", 15),
        timeout=Config.Config.get("backend/controller/postgres/request_timeout_s", 5),
        check= check_postgres_connection,
    )
    print("[INFO ]Acquired DB pool for Postgresql at='" + schema + host + ":" + str(port) + "'")

    port = Config.Config.get("backend/controller/influx/port", 8086)
    host = Config.Config.get("backend/controller/influx/hostname")
    org = Config.Config.get("backend/controller/influx/org")
    schema = Config.Config.get("backend/controller/influx/schema", "http://")
    token = Config.Config.get("backend/controller/influx/token")
    conn_uri = schema + host + ":" + str(port)
    _influx_db_client = InfluxDBClient(url=conn_uri, token=token, org=org)
    _influx_db_write_api = _influx_db_client.write_api(write_options=SYNCHRONOUS)
    print("[INFO ]Acquired DB client for InfluxDB at='" + schema + host + ":" + str(port) + "'")


def postgres_db_pool():
    return _postgres_db_pool

def influx_db_client():
    return _influx_db_client

def influx_db_write_api():
    return _influx_db_write_api

def graceful_shutdown():
    global _postgres_db_pool, _influx_db_client, _influx_db_write_api

    try:
        _postgres_db_pool.close()
        _influx_db_write_api.close()
        _influx_db_client.close()

    except TypeError as e:
        pass