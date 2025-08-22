import ast
import json
from typing import Optional

from psycopg import ServerCursor
from psycopg_pool import ConnectionPool

import backend.Config as Config
from backend.model.device import Device
from backend.model.device_state import DeviceState, DeviceStatus

db_pool: Optional[ConnectionPool] = None
devices = {}


def init_db_pool():
    global db_pool

    # TODO: Remove access to password
    host = Config.Config.get_or_default("backend/controller/db_hostname")
    dbname = Config.Config.get_or_default("backend/controller/db_name")
    user = Config.Config.get_or_default("backend/controller/db_user")
    password = Config.Config.get_or_default("backend/controller/db_password")
    conn_uri = "postgresql://" + user + ":" + password + "@" + host + "/" + dbname
    db_pool = ConnectionPool(conninfo=conn_uri)


def __parse_devices(cur: ServerCursor):
    """
    Parses the output of a database call, into a dictionary of devices in dictionary form, with the device_id as the key

    If the device already exists, the data gets updated

    :return: None
    """
    global devices
    cur.execute(
        "SELECT (device_id, device_name, position_x, position_y, management_hostname, requested_metadata) FROM Analytics.devices")
    for row in cur.fetchall():
        row = row[0]
        device_id = int(row[0])

        if devices.get(device_id) is None:
            devices[device_id] = Device(
                device_id=int(row[0]),
                device_name=row[1],
                position_x=float(row[2]),
                position_y=float(row[3]),
                management_hostname=row[4],
                requested_metadata=ast.literal_eval(row[5]),
            )

        else:
            devices[device_id].device_name = row[1]
            devices[device_id].position_x = float(row[2])
            devices[device_id].position_y = float(row[3])
            devices[device_id].management_hostname = row[4]
            devices[device_id].requested_metadata = ast.literal_eval(row[5])


def __parse_link(cur: ServerCursor) -> list:
    """
    Parses the output of a database call, into a list of links in dictionary form
    :return: list of links
    """
    links = []
    cur.execute("SELECT (link_id, side_a, side_b, link_type, link_subtype) FROM Analytics.links")
    for row in cur.fetchall():
        row = row[0]
        link = {
            "id": int(row[0]),
            "side-a": int(row[1]),
            "side-b": int(row[2]),
            "link-type": row[3]
        }
        if row[4] is not None:
            link["link-subtype"] = row[4]
        links.append(link)

    return links


def __parse_groups(cur: ServerCursor) -> list:
    """
    Parses the output of a database call, into a list of device groups in dictionary form
    :return: list of groups
    """
    groups = {}
    cur.execute("SELECT (group_id, group_name, is_display_group) FROM Analytics.groups")
    for row in cur.fetchall():
        row = row[0]
        gid = int(row[0])
        groups[gid] = {
            "id": gid,
            "name": row[1],
            "is-display-group": row[2] == 't'
        }

    group_members = {}
    cur.execute("SELECT (group_id, device_id) FROM Analytics.group_members")
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

    return group_list


async def __extract_device_metadata(metrics):
    """
    Extracts from the returned ansible-metrics the fields requested for each device, and modifies the device metadata
    """
    if len(devices) == 0:
        await get_topology_as_json()

    for hostname in metrics:
        device = Device.find_by_management_hostname(devices, hostname)

        if device is None:
            continue

        for field in device.requested_metadata:
            value = metrics[hostname].get(field)
            device.metadata[field] = value


async def get_topology_as_json():
    """
    Acquires topology from database, and converts it into json
    """
    global devices

    with db_pool.connection() as conn:
        with conn.cursor() as cur:
            __parse_devices(cur)
            links = __parse_link(cur)
            groups = __parse_groups(cur)

            return {
                "devices": [devices[device_id].to_dict() for device_id in devices],
                "links": links,
                "groups": groups
            }


async def update_device_metadata(metrics, stats):
    """
    Inserts data that might change infrequently into the Postgres database, and updates local cache of devices
    :return: None
    """
    await __extract_device_metadata(metrics)

    # set state
    for device_hostname in stats:
        device = Device.find_by_management_hostname(devices, device_hostname)

        if device is None:
            continue

        device.state = stats[device_hostname]

    # Extract metrics
    with db_pool.connection() as conn, conn.cursor() as cur:
        for hostname in metrics:
            device = Device.find_by_management_hostname(devices, hostname)

            if device is None:
                continue

            cur.execute(
                """
                    UPDATE Analytics.devices SET metadata = %s WHERE device_id = %s
                """,
                (json.dumps(device.metadata), device.device_id)
            )

    conn.commit()

    print("[INFO]Updated device metadata")
