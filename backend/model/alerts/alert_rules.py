from typing import Any, Callable

from model.alerts.alert_predicate_operation import AlertPredicateOperation, AlertReduceLogic
from model.alerts.alert_predicate import AlertPredicate
from model.alerts.alert_severity import AlertSeverity


class AlertRule:
    def __init__(
            self,
            rule_id: int,
            name : str,
            requires_ack: bool,
            severity: AlertSeverity,
            target_item : int,
            reduce_logic: AlertReduceLogic,
            predicates: tuple[AlertPredicateOperation, Any, Any, str]
    ):
        self.rule_id = rule_id
        self.name = name
        self.requires_ack = requires_ack
        self.reduce_logic = reduce_logic
        self.target_item = target_item
        self.severity = severity
        self.__predicates : list[AlertPredicate] = []
        self.eval : Callable[[dict], bool]

        for predicate in predicates:
            self.__predicates.append(AlertPredicate(predicate[0], predicate[1], predicate[2], predicate[3]))

        def safe_exec_all(d: dict) -> bool:
            # noinspection PyBroadException
            try:
                return all(p.eval(d) for p in self.__predicates)
            except Exception:
                return False

        # TODO: Might be able to delete except clause, if any upstream is guaranteed to not cause an exception
        def safe_exec_any(d: dict) -> bool:
            # noinspection PyBroadException
            try:
                return any(p.eval(d) for p in self.__predicates)
            except Exception:
                return False

        match reduce_logic:
            case AlertReduceLogic.ALL:
                self.eval = safe_exec_all

            case AlertReduceLogic.ANY:
                self.eval = safe_exec_any

            case _:
                # keep the "unreachable" code, in case new variants are added, the code won't fail silently
                # noinspection PyUnreachableCode
                raise Exception("Unhandled AlertBooleanOperation variant")

    def raising_values(self, d: dict) -> list[tuple]:
        """Evaluates manually each predicate of the rule, 
        and gathers which predicates caused the alert to raise

        Args:
            d (dict): facts dictionary to be evaluated

        Returns:
            list: list of evaluated predicates that yielded a true value
        """
        raising = []
        for predicate in self.__predicates:
            if predicate.eval(d):
                left_value = predicate.eval_left(d)
                right_value = predicate.eval_right(d)
                raising.append((left_value, predicate.op, right_value))

        return raising

    @staticmethod
    def from_dict(d: dict) -> "AlertRule":
        return AlertRule(
            rule_id=d.get("id", -1),
            name=d.get("name", "Unnamed Rule"),
            severity=AlertSeverity.from_json(d.get("severity", "unknown")),
            target_item=d["target"],
            reduce_logic=AlertReduceLogic.from_str(d["reduce-logic"]),
            requires_ack=d["requires-ack"],
            predicates=AlertPredicate.from_dict(d["predicates"])
        )

