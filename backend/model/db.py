import json
from typing import Optional

from influxdb_client import InfluxDBClient, Point, WriteApi
from influxdb_client.client.write_api import SYNCHRONOUS

from psycopg import ServerCursor
from psycopg_pool import ConnectionPool

import backend.Config as Config
from backend.model.device import Device
from backend.model.cache import cache
from backend.model.device_configuration import DeviceConfiguration
from backend.model.device_state import DeviceStatus

# TODO: Check when DB handle is no longer valid
postgres_db_pool: Optional[ConnectionPool] = None
influx_db_client: Optional[InfluxDBClient] = None
influx_db_write_api : Optional[WriteApi]   = None


def init_db_pool():
    global postgres_db_pool, influx_db_client, influx_db_write_api

    # TODO: Remove access to password
    port     = Config.Config.get("backend/controller/postgres/port", 5432)
    host     = Config.Config.get("backend/controller/postgres/hostname")
    dbname   = Config.Config.get("backend/controller/postgres/name")
    user     = Config.Config.get("backend/controller/postgres/user")
    password = Config.Config.get("backend/controller/postgres/password")
    schema   = Config.Config.get("backend/controller/postgres/schema", "postgresql://")
    conn_uri = schema + user + ":" + password + "@" + host + ":" + str(port) + "/" + dbname
    postgres_db_pool  = ConnectionPool(conninfo=conn_uri)
    print("[INFO ]Acquired DB pool for Postgresql at='"+schema+host+":"+str(port)+"'")

    port     = Config.Config.get("backend/controller/influx/port", 8086)
    host     = Config.Config.get("backend/controller/influx/hostname")
    org      = Config.Config.get("backend/controller/influx/org")
    schema   = Config.Config.get("backend/controller/influx/schema", "http://")
    token    = Config.Config.get("backend/controller/influx/token")
    conn_uri = schema + host + ":" + str(port)
    influx_db_client = InfluxDBClient(url=conn_uri, token=token, org=org)
    influx_db_write_api = influx_db_client.write_api(write_options=SYNCHRONOUS)
    print("[INFO ]Acquired DB client for InfluxDB at='" + schema + host + ":" + str(port) + "'")


def __parse_devices(cur: ServerCursor):
    """
    Parses the output of a database call, into a dictionary of devices in dictionary form, with the device_id as the key

    If the device already exists, the data gets updated

    :return: None
    """
    devices = cache.devices
    cur.execute(
        """
            SELECT Analytics.devices.device_id, device_name, position_x, position_y, latitude, longitude, management_hostname, requested_metadata, requested_metrics, available_values 
                FROM Analytics.devices
                JOIN Analytics.device_configuration ON Analytics.devices.device_id = Analytics.device_configuration.device_id;
        """)
    for row in cur.fetchall():
        device_id = int(row[0])

        if devices.get(device_id) is None:
            devices[device_id] = Device(
                device_id=int(row[0]),
                device_name=row[1],
                position_x=float(row[2]),
                position_y=float(row[3]),
                latitude=float(row[4]),
                longitude=float(row[5]),
                management_hostname=row[6],
                configuration=DeviceConfiguration(
                    requested_metadata=set(row[7]),
                    requested_metrics=set(row[8]),
                    available_values=set(row[9]),
                    data_sources=set(), # TODO: Data sources from DB
                )
            )

        else:
            devices[device_id].device_name = row[1]
            devices[device_id].position_x = float(row[2])
            devices[device_id].position_y = float(row[3])
            devices[device_id].latitude = float(row[4])
            devices[device_id].longitude = float(row[5])
            devices[device_id].management_hostname = row[6]
            devices[device_id].configuration = DeviceConfiguration(
                requested_metadata=set(row[7]),
                requested_metrics=set(row[8]),
                available_values=set(row[9]),
                data_sources=set(),  # TODO: Data sources from DB
            )

    cur.execute(
        """
            SELECT device_id, data_source FROM Analytics.device_data_sources;
        """)
    for row in cur.fetchall():
        device_id = int(row[0])

        if devices.get(device_id) is not None:
            devices[device_id].configuration.data_sources.add(row[1])


def __parse_device_datasource(cur: ServerCursor):
    """
    Parses the output of a database call, reading which data sources are used for each device

    If the device already exists, the data gets updated

    :return: None
    """
    devices = cache.devices
    cur.execute("SELECT device_id, data_source FROM Analytics.device_data_sources")
    for row in cur.fetchall():
        device_id = int(row[0])

        source : set = devices[device_id].configuration.data_sources
        source.add(row[1])


def __parse_link(cur: ServerCursor):
    """
    Parses the output of a database call, into a list of links in dictionary form
    :return: list of links
    """
    links = []
    cur.execute("SELECT link_id, side_a, side_b, side_a_iface, side_b_iface, link_type, link_subtype FROM Analytics.links")
    for row in cur.fetchall():
        link = {
            "id": int(row[0]),
            "side-a": int(row[1]),
            "side-b": int(row[2]),
            "side-a-iface": row[3],
            "side-b-iface": row[4],
            "link-type": row[5]
        }
        if row[6] is not None:
            link["link-subtype"] = row[6]
        links.append(link)
    cache.links = links


def __parse_groups(cur: ServerCursor):
    """
    Parses the output of a database call, into a list of device groups in dictionary form
    :return: list of groups
    """
    groups = {}
    cur.execute("SELECT group_id, group_name, is_display_group FROM Analytics.groups")
    for row in cur.fetchall():
        gid = int(row[0])
        groups[gid] = {
            "id": gid,
            "name": row[1],
            "is-display-group": row[2] == 't'
        }

    group_members = {}
    cur.execute("SELECT (group_id, item_id) FROM Analytics.group_members")
    for row in cur.fetchall():
        row = row[0]
        gid = int(row[0])
        if group_members.get(gid) is None:
            group_members[gid] = []

        group_members[gid].append(int(row[1]))

    # denormalization of database
    group_list = []
    for group in groups:
        # groups[group] # "id": 1, "name": "wassup", "is-display-group":yey-ya

        # if not empty, add it, brah
        if group_members.get(groups[group]["id"]) is not None:
            groups[group]["members"] = group_members[groups[group]["id"]]

        group_list.append(groups[group])

    cache.groups = group_list


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


def update_topology_cache():
    if not cache.should_update:
        return

    print("[INFO ]Updating topology cache")

    with postgres_db_pool.connection() as conn:
        with conn.cursor() as cur:
            __parse_devices(cur)
            __parse_device_datasource(cur)
            __parse_link(cur)
            __parse_groups(cur)


def get_topology_as_json():
    """
    Acquires topology from database, and converts it into json
    """
    [devices, links, groups] = cache.topology

    update_topology_cache()

    return {
        "devices": [devices[device_id].to_dict() for device_id in devices],
        "links": links,
        "groups": groups
    }


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
    with postgres_db_pool.connection() as conn, conn.cursor() as cur:
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
    bucket = Config.Config.get("backend/controller/influx/bucket")
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

        influx_db_write_api.write(bucket=bucket, org="C5i", record=point)