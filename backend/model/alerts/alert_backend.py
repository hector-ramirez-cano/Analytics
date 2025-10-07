import asyncio
import string
import random
from typing import Literal, Any

from backend.model.alerts.alert_level import AlertLevel
from backend.model.alerts.alert_operations import AlertOperations
from backend.model.alerts.alert_rules import AlertRules
import backend.model.db.alerts as alerts
from backend.model.fact_gathering.fact_gathering import FactGatheringBackend


class AlertBackend:
    __instance = None


    def __new__(cls, *args, **kwargs):
        if cls.__instance is None:
            cls.__instance = super(AlertBackend, cls).__new__(cls)
            cls.__instance.facts_rules   = []
            cls.__instance.syslog_rules  = []
            cls.__instance.rules         = {}

        return cls.__instance

    @staticmethod
    def init():
        rules = alerts.update_alert_config()

        for rule in rules:
            AlertBackend().load_from_json(rule[0], rule[1], rule[2], rule[3])

        # Register FactGatheringListener
        FactGatheringBackend.register_listener(AlertBackend.eval_facts)


    @staticmethod
    async def eval_facts(facts: dict):
        print("Hello from the other side")

    def load_rule(self,
            rule_id: int,
            name: str,
            requires_ack: bool,
            level: AlertLevel,
            target_item: int,
            predicates: list[tuple[AlertOperations, Any, Any, str]],
            data_source: Literal["facts", "syslog"],
        ):
        """
        Creates a new rule
        :param rule_id database rule id
        :param name display name of the rule
        :param requires_ack whether the alert requires to be acked before it can be dismissed
        :param level AlertLevel to be triggered upon positive evaluation of the rule
        :param target_item target device or group to which the rule will be applied to
        :param data_source source from which to extract data
        :param predicates list of tuples of predicates to be evaluated
        """
        rule = AlertRules(rule_id, name, requires_ack, level, target_item, predicates)
        self.rules[rule_id] = rule
        match data_source:
            case "facts":
                self.__instance.facts_rules.append(rule)
                return

            case "syslog":
                self.__instance.syslog_rules.append(rule)
                return

            case _:
                # noinspection PyUnreachableCode
                raise "Unhandled data source"


    def load_from_json(self, rule_id: int, name: str, requires_ack: bool, definition: dict):
        level       = AlertLevel.from_string(definition["level"])
        target_item = definition["target"]
        data_source = definition["source"]

        if name is None:
            chars = string.ascii_letters + string.digits
            name = "rule_"+''.join(random.choices(chars, k=12))
            print(f"[WARN ][ALERTS][LOADS]Unnamed rule found..., adding random name = {name}")

        if level is None:
            print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' contains invalid level, skipping...")
            return

        predicates: list[tuple[AlertOperations, Any, Any, str]] = []
        for predicate in definition["predicates"]:
            left        = predicate["left"]
            right       = predicate["right"]
            left_const  = left is str and "&" in predicate["left"]
            right_const = right is str and "&" in predicate["right"]
            op          = AlertOperations[predicate["op"]]
            const_str   = "left" if left_const else "right" if right_const else ""

            if op is None:
                print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' contains invalid op, skipping...")
                return

            if left is None or right is None or left == "" or right == "":
                print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' does not contain left or right param, skipping...")
                return

            if left_const == right_const == True:
                print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' has both sides of the operand as const, skipping...")
                return

            predicates.append((op, left, right, const_str))

        self.load_rule(rule_id, name, requires_ack, level, target_item, predicates, data_source)


    def eval_rules(self):
        # need 2 things: facts and syslog
        # observer-listener pattern
        # TODO: Implementation
        pass