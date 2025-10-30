"""Database commit operations of modified data

Raises:
    Exception: failed to commit
    Exception: failed to commit
    Exception: failed to commit
    Exception: failed to commit

Returns:
    _type_: None
"""

import json

from model.data.device import Device
from model.data.group import Group
from model.data.link import Link
from model.db.pools import postgres_db_pool
from model.db.update_devices import update_topology_cache
from model.alerts.alert_backend import AlertBackend

async def commit(data: dict) -> tuple[bool, str]:
    """_Commits to the database the changes_

    Args:
        data (dict): dictionary of changes with 4 keys ["topology-changes", "topology-deletions", "ruleset-changes", "ruleset-deletions"]

    Raises:
        Exception: Failed to commit to database

    Returns:
        tuple[bool, str]: success?, err_msg

    """
    result: bool
    msg : str
    with postgres_db_pool().connection() as conn:
        try:
            topology_changes = data["topology-changes"]
            topology_deletions = data["topology-deletions"]
            ruleset_changes = data["ruleset-changes"]
            ruleset_deletions = data["ruleset-deletions"]

            if devices := topology_changes.get("devices", False):
                devices = [Device.from_dict(d) for d in devices]
                result, msg = commit_devices(devices, conn)

                if not result:
                    raise Exception(msg)

            if groups := topology_changes.get("groups", False):
                groups = [Group.from_dict(d) for d in groups]
                result, msg = commit_groups(groups, conn)

                if not result:
                    raise Exception(msg)

            if links := topology_changes.get("links", False):
                links = [Link.from_dict(d) for d in links]
                result, msg = commit_links(links, conn)

                if not result:
                    raise Exception(msg)

            if rules := ruleset_changes.get("rules", False):
                result, msg = commit_rules(rules, conn)

                if not result:
                    raise Exception(msg)

            # Deletions

            for group in topology_deletions.get("groups", []):
                __delete_group(group.from_dict(group).group_id, conn)

            for link in topology_deletions.get("links", []):
                __delete_link(Link.from_dict(link).link_id, conn)

            for device in topology_deletions.get("devices", []):
                __delete_device(Device.from_dict(device).device_id, conn)

            for rule in ruleset_deletions.get("rules", []):
                __delete_rule(rule.rule_id, conn)


        # if any step fails, rollback
        except Exception as e:
            conn.rollback()
            return False, str(e)

    update_topology_cache(forced=True)
    AlertBackend.update_ruleset(forced=True)

    return True, ""


def commit_devices(devices: list[Device], conn) -> tuple[bool, str]:
    """_Commits to the database the device changes_

    Args:
        devices (list[Device]): devices
        conn: database connection

    Returns:
        tuple[bool, str]: success?, err_msg
    """
    print("[INFO ]Commit device changes following user configuration from UI")
    with conn.cursor() as cur:
        for device in devices:
            __commit_device(device, cur)

    return True, ""


def commit_links(links: list[Link], conn) -> tuple[bool, str]:
    """_Commits to the database the link changes_

    Args:
        links (list[Link]): links
        conn: database connection

    Returns:
        tuple[bool, str]: success?, err_msg
    """
    with conn.cursor() as cur:
        for link in links:
            __commit_link(link, cur)

    return True, ""


def commit_groups(groups: list[Group], conn) -> tuple[bool, str]:
    """_Commits to the database the group changes_

    Args:
        groups (list[Group]): groups
        conn: database connection

    Returns:
        tuple[bool, str]: success?, err_msg
    """
    with conn.cursor() as cur:
        for group in groups:
            __commit_group(group, cur)
    return True, ""

def commit_rules(rules: list[dict], conn) -> tuple[bool, str]:
    """_Commits to the database the rule changes_

    Args:
        rules (list[dict]): rules
        conn: database connection

    Returns:
        tuple[bool, str]: success?, err_msg
    """
    with conn.cursor() as cur:
        for rule in rules:
            __commit_rule(rule, cur)

    return True, ""

def __commit_device(device: Device, cur):
    if device.device_id <= 0:
        cur.execute(
            """
                INSERT INTO Analytics.devices
                    (device_name, position_x, position_y,
                    latitude, longitude,
                    management_hostname,
                    requested_metadata, requested_metrics, available_values)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING device_id
            """, (
                device.device_name, device.position_x, device.position_y,
                device.latitude, device.longitude,
                device.management_hostname,
                json.dumps(list(device.configuration.requested_metadata)),
                json.dumps(list(device.configuration.requested_metrics)),
                json.dumps(list(device.configuration.available_values)),
                device.device_id
            ))
        device.device_id = cur.fetchone()[0]

    else:
        cur.execute(
            """
                UPDATE Analytics.devices
                SET device_name=%s, position_x=%s, position_y=%s,
                    latitude=%s, longitude=%s,
                    management_hostname=%s,
                    requested_metadata=%s,
                    requested_metrics=%s,
                    available_values=%s
                WHERE device_id =%s
            """, (
                device.device_name, device.position_x, device.position_y,
                device.latitude, device.longitude,
                device.management_hostname,
                json.dumps(list(device.configuration.requested_metadata)),
                json.dumps(list(device.configuration.requested_metrics)),
                json.dumps(list(device.configuration.available_values)),
                device.device_id
            ))

    cur.execute(
        "DELETE FROM Analytics.device_data_sources WHERE device_id = %s",
        (device.device_id,)
    )
    for source in device.configuration.data_sources:
        cur.execute(
        """
            INSERT INTO Analytics.device_data_sources
                (device_id, data_source)
            VALUES
                (%s, %s)
            ON CONFLICT (device_id, data_source) DO NOTHING
        """, (device.device_id, source)
        )

def __commit_link(link: Link, cur):
    if link.link_id <= 0:
        cur.execute(
            """
                INSERT INTO Analytics.links
                    (side_a, side_b, side_a_iface, side_b_iface, link_type, link_subtype)
                VALUES
                    (%s, %s, %s, %s, %s, %s)
            """, (
                link.side_a_id, link.side_b_id, link.side_a_iface,
                link.side_b_iface, link.link_type, link.link_subtype
            ))

    else:
        cur.execute(
            """
                UPDATE Analytics.links
                    SET side_a = %s, side_b = %s, side_a_iface = %s,
                    side_b_iface = %s, link_type = %s, link_subtype = %s
                WHERE link_id = %s
            """, (
                link.side_a_id, link.side_b_id, link.side_a_iface,
                link.side_b_iface, link.link_type, link.link_subtype,
                link.link_id
            ))

def __commit_group(group: Group, cur):
    if group.group_id <= 0:
        cur.execute(
            """
                INSERT INTO Analytics.groups
                    (group_name, is_display_group)
                VALUES
                    (%s, %s)
                RETURNING group_id
            """, (group.name, group.is_display_group)
        )
        group_id = cur.fetchone()[0]
        for member in group.members:
            cur.execute(
                """
                    INSERT INTO Analytics.group_members
                        (group_id, item_id)
                    VALUES
                        (%s, %s)
                    ON CONFLICT (group_id, item_id) DO NOTHING
                """, (group_id, member))

    else:
        cur.execute(
            """
                UPDATE Analytics.groups
                SET group_name = %s, is_display_group = %s
                WHERE group_id = %s
            """, (group.name, group.is_display_group, group.group_id)
        )

        cur.execute(
            "DELETE FROM Analytics.group_members WHERE group_id = %s", (group.group_id,)
        )
        for member in group.members:
            cur.execute(
                """
                    INSERT INTO Analytics.group_members
                        (group_id, item_id)
                    VALUES
                        (%s, %s)
                    ON CONFLICT (group_id, item_id) DO NOTHING
                """, (group.group_id, member))

def __commit_rule(rule, cur):
    if rule["id"] <= 0:
        cur.execute(
            """
            INSERT INTO Analytics.alert_rules
                (rule_name, requires_ack, rule_definition)
            VALUES
                (%s, %s, %s)
            """,
            (rule["name"], rule["requires-ack"], json.dumps(rule["rule-definition"]))
        )

    else:
        cur.execute(
            """
            UPDATE Analytics.alert_rules
            SET rule_name=%s, requires_ack=%s, rule_definition=%s
            WHERE rule_id =%s
            """,
            (rule["name"], rule["requires-ack"], json.dumps(rule["rule-definition"]), rule["id"])
        )

def __delete_device(device_id: int, conn):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM Analytics.Devices WHERE device_id = %s", (device_id,))

def __delete_link(link_id : int, conn):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM Analytics.links WHERE link_id = %s", (link_id,))

def __delete_group(group_id : int, conn):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM Analytics.groups WHERE group_id = %s", (group_id, ))

def __delete_rule(rule_id: int, conn):
    with conn.cursor() as cur:
        cur.execute("DELETE FROM Analytics.alert_rules WHERE rule_id = %s", (rule_id,))
