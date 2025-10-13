import json

from model.data.device import Device
from model.data.group import Group
from model.data.link import Link
from model.db.pools import postgres_db_pool
from model.db.update_devices import update_topology_cache

async def commit(data: dict) -> tuple[bool, str]:
    with postgres_db_pool().connection() as conn:
        try:
            changes = data["changes"]
            deleted = data["deleted"]

            if devices := changes.get("devices", False):
                devices = [Device.from_dict(d) for d in devices]
                result, msg = await commit_devices(devices, conn)

                if not result:
                    raise Exception(msg)

            if groups := changes.get("groups", False):
                groups = [Group.from_dict(d) for d in groups]
                result, msg = await commit_groups(groups, conn)

                if not result:
                    raise Exception(msg)

            if links := changes.get("links", False):
                links = [Link.from_dict(d) for d in links]
                result, msg = await commit_links(links, conn)

                if not result:
                    raise Exception(msg)

            if rules := changes.get("rules", False):
                result, msg = await commit_rules(rules, conn)

                if not result:
                    raise Exception(msg)

            # Deletions

            for group in deleted.get("groups", []):
                __delete_group(group.from_dict(group).group_id, conn)

            for link in deleted.get("links", []):
                __delete_link(Link.from_dict(link).link_id, conn)

            for device in deleted.get("devices", []):
                __delete_device(Device.from_dict(device).device_id, conn)

            for rule in deleted.get("rules", []):
                __delete_rule(rule.rule_id, conn)


        # if any step fails, rollback
        except Exception as e:
            conn.rollback()
            return False, str(e)

        # force update of local cache from db
        update_topology_cache(forced=True)


        return True, ""


async def commit_devices(devices: list[Device], conn) -> tuple[bool, str]:
    print("[INFO ]Commit device changes following user configuration from UI")
    with conn.cursor() as cur:
        for device in devices:
            __commit_device(device, cur)

    return True, ""


async def commit_links(links: list[Link], conn) -> tuple[bool, str]:
    with conn.cursor() as cur:
        for link in links:
            __commit_link(link, cur)

    return True, ""


async def commit_groups(groups: list[Group], conn) -> tuple[bool, str]:
    with conn.cursor() as cur:
        for group in groups:
            __commit_group(group, cur)
    return True, ""

def commit_rules(rules: list[dict], conn) -> tuple[bool, str]:
    with conn.cursor() as cur:
        for rule in rules:
            __commit_rule(rule, cur)

    return True, ""

def __commit_device(device: Device, cur):
    if device.device_id >= 0:
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
        """, (device.device_id, source)
        )

def __commit_link(link: Link, cur):
    if link.link_id >= 0:
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
    if group.group_id >= 0:
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
                """, (group.group_id, member))

def __commit_rule(rule, cur):
    if rule["id"] >= 0:
        cur.execute(
            """
            INSERT INTO Analytics.alert_rules
                (rule_name, requires_ack, rule_definition)
            VALUES
                (%s, %s, %s)
            """,
            (rule["name"], rule["requires-ack"], rule["rule-definition"])
        )

    else:
        cur.execute(
            """
            UPDATE Analytics.alert_rules
            SET rule_name=%s, requires_ack=%s, rule_definition=%s
            WHERE rule_id =%s
            """,
            (rule["name"], rule["requires-ack"], rule["rule-definition"], rule["id"])
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
