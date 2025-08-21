from psycopg import ServerCursor
from psycopg_pool import ConnectionPool

import backend.Config as Config


db_pool = None

def init_db_pool():
    global db_pool

    # TODO: Remove access to password
    host = Config.Config.get_or_default("backend/controller/db_hostname")
    dbname = Config.Config.get_or_default("backend/controller/db_name")
    user = Config.Config.get_or_default("backend/controller/db_user")
    password = Config.Config.get_or_default("backend/controller/db_password")
    conn_uri = "postgresql://" + user + ":" + password + "@" + host + "/" + dbname
    db_pool = ConnectionPool(conninfo=conn_uri)

def parse_devices(cur: ServerCursor) -> list :
    """
    Parses the output of a database call, into a list of devices in dictionary form
    :return: list of devices
    """
    devices = []
    cur.execute("SELECT (device_id, device_name, position_x, position_y) FROM Analytics.devices")
    for row in cur.fetchall():
        row = row[0]
        devices.append({
            "id": int(row[0]),
            "name": row[1],
            "coordinates": [ float(row[2]), float(row[3]) ]
        })

    return devices


def parse_link(cur: ServerCursor) -> list:
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


def parse_groups(cur: ServerCursor) -> list:
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
            "is-display-group": row[2]=='t'
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

async def get_topology_as_json():
    """
    Acquires topology from database, and converts it into json
    """

    with db_pool.connection() as conn:
        with conn.cursor() as cur:
            devices = parse_devices(cur)
            links   = parse_link(cur)
            groups  = parse_groups(cur)

            return {"devices": devices, "links": links, "groups": groups }

async def insert_device_metadata(metrics):
    """
    Inserts data that might change infrequently into the Postgres database
    :return: None
    """
