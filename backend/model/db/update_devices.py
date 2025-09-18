import json

from influxdb_client import Point

from backend.Config import Config
from backend.model.cache import cache
from backend.model.db import update_device
from backend.model.db.pools import postgres_db_pool, influx_db_write_api
from backend.model.device import Device
from backend.model.device_state import DeviceStatus


def update_topology_cache():
    if not cache.should_update:
        return

    print("[INFO ]Updating topology cache")

    with postgres_db_pool().connection() as conn:
        with conn.cursor() as cur:
            update_device.parse_devices(cur)
            update_device.parse_device_datasource(cur)
            update_device.parse_link(cur)
            update_device.parse_groups(cur)


def __extract_device_metadata(metrics):
    """
    Extracts from the returned ansible-metrics the fields requested for each device, and modifies the device metadata
    """
    devices = cache.devices

    for hostname in metrics:
        device = Device.find_by_management_hostname(devices, hostname)

        if device is None:
            continue

        for field in device.configuration.requested_metadata:
            value = metrics[hostname].get(field)
            device.metadata[field] = value


def update_device_metadata(exposed_metrics: dict, metrics : dict, status: dict):
    """
    Inserts data that might change infrequently into the Postgres database, and updates local cache of devices
    :return: None
    """
    __extract_device_metadata(metrics)
    devices = cache.devices

    for device_hostname in status:
        device = Device.find_by_management_hostname(devices, device_hostname)

        if device is None:
            continue

        # set state
        device.state = DeviceStatus.make_from_dict(status[device_hostname])

        # set available_values, but only if it was not null since last call
        available_values = exposed_metrics.get(device_hostname)
        if available_values is not None:
            device.available_values = available_values

    # Extract metrics
    with postgres_db_pool().connection() as conn, conn.cursor() as cur:
        # Metrics will contain only devices for which connection was successful
        for hostname in metrics:
            device = Device.find_by_management_hostname(devices, hostname)

            if device is None:
                continue

            cur.execute(
                """
                    UPDATE Analytics.devices SET metadata = %s WHERE device_id = %s
                """,
                (json.dumps(device.available_values), device.device_id)
            )

            cur.execute(
                """
                    UPDATE Analytics.device_configuration SET available_values = %s WHERE device_id = %s
                """,
                (json.dumps(device.available_values), device.device_id)
            )

    conn.commit()

    print("[INFO ]Updated device metadata")


def update_device_analytics(metrics):
    """
    Inserts datapoints into influxdb bucket
    """
    bucket = Config.get("backend/controller/influx/bucket")
    devices = cache.devices

    # Metrics will contain only devices for which connection was successful
    for hostname in metrics:
        device = Device.find_by_management_hostname(devices, hostname)

        if device is None:
            continue

        point = (
            Point("avg_latency")
            .tag("rtt-latency", hostname)
            .field("rtt-latency", float(metrics[hostname].get("avg_latency", [0])[0]))
        )

        influx_db_write_api().write(bucket=bucket, org="C5i", record=point)

