import json

from influxdb_client import Point

from Config import Config
from model.cache import Cache
from model.db import fetch_topology
from model.db.pools import postgres_db_pool, influx_db_write_api
from model.data.device import Device
from model.device_state import DeviceStatus

def update_topology_cache(forced: bool = False):
    if not Cache().should_update and not forced:
        return

    print("[INFO ]Updating topology cache")

    with postgres_db_pool().connection() as conn:
        with conn.cursor() as cur:
            fetch_topology.parse_devices(cur)
            fetch_topology.parse_device_datasource(cur)
            fetch_topology.parse_link(cur)
            fetch_topology.parse_groups(cur)


def update_device_metadata(exposed_metrics: dict, metrics : dict, status: dict):
    """
    Inserts data that might change infrequently into the Postgres database, and updates local cache of devices
    :return: None
    """
    __extract_device_metadata(metrics)
    devices = Cache().devices

    for device_hostname in status:
        device = Device.find_by_management_hostname(devices, device_hostname)

        if device is None:
            continue

        # set state
        device.state = DeviceStatus.make_from_dict(status[device_hostname])

        # set available_values, override if last gotten values were not null
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

            # FIXME: metadata contains every available value, as opposed to only requested metadata
            cur.execute(
                """
                    UPDATE Analytics.devices 
                    SET metadata = %s, available_values = %s 
                    WHERE device_id = %s
                """,
                (
                    json.dumps(device.available_values), json.dumps(device.available_values),
                    device.device_id
                )
            )

    conn.commit()

    print("[INFO ]Updated device metadata")


def update_device_analytics(metrics):
    """
    Inserts datapoints into influxdb bucket
    """
    bucket = Config.get("backend/controller/influx/bucket")
    devices = Cache().devices

    # List for batched writes
    points = []

    # Metrics will contain only devices for which connection was successful
    for hostname in metrics:
        device = Device.find_by_management_hostname(devices, hostname)

        if device is None:
            continue

        if len(device.configuration.requested_metrics) == 0:
            continue

        point = Point("metrics").tag("device_id", device.device_id)

        # add them fields on that there point
        for requested_metric in device.configuration.requested_metrics:
            value = metrics.get(hostname, {}).get(requested_metric, [0])
            point.field(requested_metric, value)

        points.append(point)

    # tell this distinguished gentleman about the point
    influx_db_write_api().write(bucket=bucket, org="C5i", record=points)


def __extract_device_metadata(metrics):
    """
    Extracts from the returned ansible-metrics the fields requested for each device, and modifies the device metadata
    """
    devices = Cache().devices

    for hostname in metrics:
        device = Device.find_by_management_hostname(devices, hostname)

        if device is None:
            continue

        for field in device.configuration.requested_metadata:
            value = metrics[hostname].get(field)
            device.metadata[field] = value
