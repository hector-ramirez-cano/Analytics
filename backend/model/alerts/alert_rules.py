from typing import Literal, Any

from backend.model.alerts.alert_level import AlertLevel
from backend.model.alerts.alert_operations import AlertOperations
from backend.model.alerts.alert_predicate import AlertPredicate


class AlertRules:
    def __init__(
            self,
            rule_id: int,
            name : str,
            requires_ack: bool,
            level: AlertLevel,
            target_item : int,
            predicates: tuple[AlertOperations, Any, Any, str]
    ):
        self.rule_id = rule_id
        self.name = name
        self.requires_ack = requires_ack
        self.__target = target_item,
        self.__level = level
        self.__predicates : list[AlertPredicate] = []

        for predicate in predicates:
            self.__predicates.append(AlertPredicate(predicate[0], predicate[1], predicate[2], predicate[3]))
