
from psycopg import ServerCursor

from backend.model.cache import cache
from backend.model.device import Device
from backend.model.device_configuration import DeviceConfiguration



def parse_devices(cur: ServerCursor):
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


def parse_device_datasource(cur: ServerCursor):
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


def parse_link(cur: ServerCursor):
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


def parse_groups(cur: ServerCursor):
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

