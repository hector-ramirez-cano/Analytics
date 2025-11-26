from typing import Optional

from influxdb_client import WriteApi, InfluxDBClient, InfluxDBClient, BucketRetentionRules
from influxdb_client.client.write_api import SYNCHRONOUS
from influxdb_client.client.query_api import QueryApi
from influxdb_client.client.tasks_api import TasksApi

import Config

_influx_db_client: Optional[InfluxDBClient] = None
_influx_db_write_api : Optional[WriteApi]   = None
_influx_db_query_api : Optional[QueryApi]   = None
_influx_db_task_api  : Optional[TasksApi]   = None

def init_db_pool():
    global _influx_db_write_api, _influx_db_client, _influx_db_query_api, _influx_db_task_api

    port = Config.Config.get("backend/controller/influx/port", 8086)
    host = Config.Config.get("backend/controller/influx/hostname")
    org = Config.Config.get("backend/controller/influx/org")
    schema = Config.Config.get("backend/controller/influx/schema", "http://")
    token = Config.Config.get("backend/controller/influx/operator_token")
    conn_uri = schema + host + ":" + str(port)
    _influx_db_client = InfluxDBClient(url=conn_uri, token=token, org=org)
    _influx_db_write_api = _influx_db_client.write_api(write_options=SYNCHRONOUS)
    _influx_db_query_api = _influx_db_client.query_api()
    _influx_db_task_api  = _influx_db_client.tasks_api()
    print("[INFO ]Acquired DB client for InfluxDB at='" + schema + host + ":" + str(port) + "'")

    __init_buckets(org)
    __init_baseline_tasks(org)


def __init_baseline_tasks(org: str):
    """
        Creates tasks for aggregate of _Numeric_ metrics, that are set to execute every 1h
        These metrics are set into another bucket, "baselines"
    """
    tasks_api = influx_db_tasks_api()
    orgs_api = influx_db_client().organizations_api()
    organization =next((o for o in orgs_api.find_organizations() if o.name == org), None)
    aggregate_windows = ("1m", "15m", "1h", "1d","15d", "30d", "180d", "365d")

    for window in aggregate_windows:
        task_name = f"task_baseline_{window}"
        task_definition = f"""

            import "types"

            numeric =
                from(bucket: "analytics")
                    |> range(start: -{window})
                    |> filter(fn: (r) => r._measurement == "metrics")
                    |> filter(fn: (r) => types.isNumeric(v: r._value))

            numeric
                |> aggregateWindow(every: {window}, fn: mean, createEmpty: false)
                |> map(fn: (r) => ({{
                    r with
                    window: "{window}",
                    device_id: r.device_id
                }}))
                |> to(
                    bucket: "baselines",
                    tagColumns: ["window", "device_id"]
                )
        """

        existing_tasks = tasks_api.find_tasks(name=task_name)

        if not existing_tasks:
            task = tasks_api.create_task_every(name=task_name, flux=task_definition, every="15m", organization=organization)
            tasks_api.run_manually(task.id)
            tasks_api.run_manually(task.id)
            print(f"[PRELUDE][INFO ][InfluxDB]Created task: {task_name}")
        else:
            print(f"[PRELUDE][INFO ][InfluxDB]Task '{task_name}' already exists. Skipping creation.")


def __init_buckets(org: str):
    client = influx_db_client()
    buckets_api = client.buckets_api()

    for required in ["analytics", "baselines"]:
        existing = buckets_api.find_bucket_by_name(required)

        if existing:
            print(f"[PRELUDE][INFO ][InfluxDB]Bucket '{required}' already exists. Skipping creation.")

        else:
            buckets_api.create_bucket(
                bucket_name=required,
                org=org,
                retention_rules=[
                    BucketRetentionRules(type="expire", every_seconds=0), # infinite retention
                ]
            )
            print(f"[PRELUDE][INFO ][InfluxDB]Created bucket: {required}")

def influx_db_client():
    return _influx_db_client

def influx_db_write_api():
    return _influx_db_write_api

def influx_db_query_api():
    return _influx_db_query_api

def influx_db_tasks_api():
    return _influx_db_task_api

def graceful_shutdown():
    global _postgres_db_pool, _influx_db_client, _influx_db_write_api

    try:
        _influx_db_write_api.close()
        _influx_db_client.close()

    except TypeError as _:
        pass

def main():
    init_db_pool()

if __name__ == "__main__":
    main()