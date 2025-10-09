from dataclasses import dataclass
from typing import Any

from backend.model.alerts.alert_rules import AlertRule
from backend.model.data.device import Device


@dataclass
class Group:
    def __init__(self, group_id: int, name: str, members: list[int], is_display_group: bool):
        self.group_id = group_id
        self.name = name
        self.members = members
        self.is_display_group = is_display_group


    def eval_rule(self, rule: AlertRule, d: dict, get_item_fn) -> tuple[bool, tuple[Device]]:
        """
        Evaluates the rule for every member
        :param rule AlertRule to evaluate for truthness
        :param d dictionary to be passed to the rule for matching
        :param get_item_fn function to call to fetch a more groups or devices

        :returns: tuple[bool, Group|Device] (any_true?, which_true?)

        Leverages CPython functions for fast execution
        Equivalent python code:
            for item_id in self.members:
                item = cache.get_item(item_id)

                if item.eval_rule(rule, d):
                    return True, item
        """
        matched_devices = tuple(
            device
            for item_id in self.members
            if (item := get_item_fn(item_id)).eval_rule(rule, d, get_item_fn)[0]
            for device in item.eval_rule(rule, d, get_item_fn)[1]
        )
        return bool(matched_devices), matched_devices

    def to_json(self):
        return {
            "id": self.group_id,
            "name": self.name,
            "is-display-group": self.is_display_group,
            "members": self.members,
        }