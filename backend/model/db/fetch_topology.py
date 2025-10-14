
from psycopg import ServerCursor

from model.cache import cache
from model.data.device import Device
from model.data.group import Group
from model.data.link import Link
from model.device_configuration import DeviceConfiguration
from model.db.update_devices import update_topology_cache

def get_topology_as_dict():
    """
    Acquires topology from database, and converts it into a dict
    """
    devices, links, groups = cache.topology

    update_topology_cache()

    return {
        "devices": [device.to_dict() for device in devices.values()],
        "links": [link.to_dict() for link in links.values()],
        "groups": [group.to_dict() for group in groups.values()]
    }




def parse_devices(cur: ServerCursor):
    """
    Parses the output of a database call, into a dictionary of devices in dictionary form, with the device_id as the key

    If the device already exists, the data gets updated

    updates cache as result
    :return: None
    """
    devices = cache.devices
    cur.execute(
        """
            SELECT Analytics.devices.device_id, device_name, position_x, position_y, latitude, longitude, management_hostname, requested_metadata, requested_metrics, available_values 
                FROM Analytics.devices;
        """)
    for row in cur.fetchall():
        device_id = int(row[0])

        # TODO: Handle snmp configuration
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
                    available_values=set(row[9]) if (row[9] is not None) else {},
                    data_sources=set(),
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
                available_values=set(row[9]) if (row[9] is not None) else {},
                data_sources=set(),
            )

    # we extract the data sources, the database is normalized, so it's a separate table
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
    Parses the output of a database call, into a dictionary of links in dictionary form, with the link id as key

    updates cache as a result
    :return: None
    """
    links = {}
    cur.execute("SELECT link_id, side_a, side_b, side_a_iface, side_b_iface, link_type, link_subtype FROM Analytics.links")
    for row in cur.fetchall():
        link = Link(
            link_id= int(row[0]),
            side_a_id = int(row[1]),
            side_b_id = int(row[2]),
            side_a_iface= row[3],
            side_b_iface= row[4],
            link_type= row[5],
            link_subtype= row[6] if row[6] is not None else ""
        )

        links[link.link_id] = link

    cache.links = links


def parse_groups(cur: ServerCursor):
    """
    Parses the output of a database call, into a list of Groups in dictionary form, with the group ID as key

    Updates cache as result
    :return: None
    """
    groups = dict[int, Group]()
    cur.execute("SELECT group_id, group_name, is_display_group FROM Analytics.groups")
    for row in cur.fetchall():
        gid = int(row[0])
        groups[gid] = Group(group_id=gid, name=row[1], members=[], is_display_group=row[2] == 't')

    group_members = {}
    cur.execute("SELECT (group_id, item_id) FROM Analytics.group_members")
    for row in cur.fetchall():
        row = row[0]
        gid = int(row[0])
        if group_members.get(gid) is None:
            group_members[gid] = []

        group_members[gid].append(int(row[1]))

    # denormalization of database
    group_list = {}
    for group in groups:
        # groups[group] # -> Group

        # if not empty, add it, brah
        if group_members.get(groups[group].group_id) is not None:
            groups[group].members = group_members[groups[group].group_id]

        group_list[groups[group].group_id] = (groups[group])

    cache.groups = group_list

    # TODO: Prevent group circular dependency
