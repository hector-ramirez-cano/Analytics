import asyncio
import string
import random
import threading
import time
from asyncio import Task
from typing import Literal, Any, Coroutine

import janus

from model.alerts.alert_event import AlertEvent
from model.alerts.alert_predicate_operation import AlertPredicateOperation, AlertReduceLogic
from model.alerts.alert_rules import AlertRule
from model.alerts.alert_severity import AlertSeverity
from model.data.device import Device
from model.data.group import Group
from model.facts.fact_gathering_backend import FactGatheringBackend
from model.syslog.syslog_backend import SyslogBackend
from model.cache import Cache
from model.db.operations import alert_operations
from Config import Config

class AlertBackend:
    __instance = None
    __last_update = 0 # Epoch

    facts_rules = {}
    syslog_rules = {}
    rules = {}
    listeners = []


    def __new__(cls, *_, **__):
        if cls.__instance is None:
            cls.__instance = super(AlertBackend, cls).__new__(cls)
            cls.__instance.facts_rules   = {}
            cls.__instance.syslog_rules  = {}
            cls.__instance.rules         = {}
            cls.__instance.listeners     = []

        return cls.__instance

    @staticmethod
    def init():
        """
        Initializes the rules from the database.
        Should be called after the database has initialized, as it fetches the rules from it.

        :returns: None
        """
        AlertBackend.update_ruleset(forced=True)


    @staticmethod
    def init_service(
            stop_event: asyncio.Event,
            syslog_queue: asyncio.Queue,
            facts_queue: asyncio.Queue,
            alerts_queue: asyncio.Queue
    ) -> tuple[Task[None], Task[None], Task[None]]:
        """
        Init for the FactGatheringBackend and SyslogBackend listeners, and the alert handler loop
        Should be called once the asyncio loop is running, as it relies on it to attach itself

        :param stop_event event that signals the tasks should exit gracefully
        :param syslog_queue queue that will be used to pass messages SyslogBackend -> AlertBackend
        :param facts_queue queue that will be used to pass messages FactGatheringBackend -> AlertBackend
        :param alerts_queue queue that will be used to pass messages AlertBackend.listeners -> AlertBackend.alert_task

        :returns: tuple[Task[None], ...] of tasks created by this service
        """
        loop = asyncio.get_event_loop()

        # Register FactGatheringListener
        FactGatheringBackend.register_listener(facts_queue)
        facts_task = loop.create_task(AlertBackend.eval_facts(stop_event, facts_queue, alerts_queue))

        # Register SyslogBackend
        SyslogBackend.register_listener(syslog_queue)
        syslog_task = loop.create_task(AlertBackend.eval_syslog(stop_event, syslog_queue, alerts_queue))

        # Create alert handler task
        alert_task = loop.create_task(AlertBackend.handle_alert_queue(stop_event, alerts_queue))

        return syslog_task, facts_task, alert_task

    @staticmethod
    def should_update() -> bool:
        return time.time() - AlertBackend.__last_update > Config.get("backend/controller/cache/cache_invalidation_s", 60)

    @staticmethod
    def update_ruleset(forced: bool):
        if (AlertBackend.should_update() or forced):
            rules = alert_operations.update_alert_config()

            for rule in rules:
                AlertBackend().load_from_json(rule[0], rule[1], rule[2], rule[3])

            AlertBackend.__last_update = time.time()


    @staticmethod
    def register_listener(queue: asyncio.Queue):
        print("[INFO ][ALERTS][WS]Registered listener")
        AlertBackend().listeners.append(queue)

    @staticmethod
    def remove_listener(queue: asyncio.Queue):
        print("[INFO ][ALERTS][WS]Removed listener")
        AlertBackend().listeners.remove(queue)

    @staticmethod
    async def notify_listeners(event: AlertEvent):
        for listener in AlertBackend().listeners:
            await listener.put(event)

    @staticmethod
    async def __eval_rules(rules : list[AlertRule], value: dict, alert_queue : asyncio.Queue):
        """
        Evaluates a rule against the rules list, and inserts a new AlertEvent if a rule is met.
        If a rule raises, it gets skipped.
        :param rules list of rules (subset) to be evaluated
        :param value input dict used to evaluate rules, as produced by the facts backend
        :param alert_queue queue to which new events will be posted to
        """
        for rule in rules:
            target: Device | Group = Cache().get_item(rule.target_item)

            try:
                result, alerting_devices = target.eval_rule(rule, value, Cache().get_item)
                if not result:
                    continue

                # rule matched, issue an alert for each target that alerted
                for device in alerting_devices:
                    # we know the rule alerted, but we want to know which predicate(s) were raised
                    predicate_values = device.which_eval_raised(rule, value)
                    predicate_values = [f"{a} {str(op)} {b}" for a, op, b in predicate_values]

                    await AlertBackend.raise_alert(rule, alert_queue, device, str(predicate_values))

            except Exception as e:
                print("[ERROR][ALERTS][RULE]Evaluation raised e=",str(e))


    @staticmethod
    async def eval_facts(stop_event : asyncio.Event, queue: asyncio.Queue, alert_queue: asyncio.Queue):
        """
        Evaluates rules for fact gathering events. Defers work and handling to __eval_rules
        :param stop_event asyncio.Event to handle graceful shutdown
        :param queue asyncio.Queue input queue from which data will be received
        :param alert_queue asyncio.Queue output queue to which alerts will be posted

        :returns: None
        """
        try:
            while not stop_event.is_set():
                value = await queue.get()
                if stop_event.is_set():
                    return

                await AlertBackend.__eval_rules(AlertBackend().facts_rules.values(), value, alert_queue)

        except Exception as e:
            print(f"[ERROR][ALERTS]registered exception e='{str(e)}'")

    @staticmethod
    async def eval_syslog(stop_event : asyncio.Event, queue: asyncio.Queue, alert_queue: asyncio.Queue):
        """
        Evaluates rules for syslog events. Defers work and handling to __eval_rules
        :param stop_event asyncio.Event to handle graceful shutdown
        :param queue asyncio.Queue input queue from which data will be received
        :param alert_queue asyncio.Queue output queue to which alerts will be posted

        :returns: None
        """
        try:
            while not stop_event.is_set():

                value = await queue.get()
                if stop_event.is_set():
                    return

                await AlertBackend.__eval_rules(AlertBackend().syslog_rules.values(), value, alert_queue)

        except Exception as e:
            print(f"[ERROR][ALERTS]registered exception e='{str(e)}'")


    @staticmethod
    async def raise_alert(rule : AlertRule, alert_queue: asyncio.Queue, device : Device, value: str):
        """
        Raises an alert and posts it to the alert_queue for processing.
        :param rule AlertRule that matched
        :param alert_queue asyncio.Queue output queue to which the event will be posted
        :param device instance of Device that matched the rule
        """
        # TODO: Change message generation
        event = AlertEvent(
            requires_ack=rule.requires_ack,
            severity=rule.severity,
            message=f"'{rule.name}' triggered for device='{device.device_name}'!",
            target_id=device.device_id,
            ack_time=None,
            rule_id = rule.rule_id,
            value=value,
        )

        # put into the queue, for someone else to handle
        await alert_queue.put(event)

        print("[INFO ][ALERTS]Issued alert=", str(event))

    @staticmethod
    async def handle_alert_queue(stop_event: asyncio.Event, queue: asyncio.Queue[AlertEvent]):
        """
        handles when an alert is raised. Once an alert is raised, this method will attempt to post it to the DB and ws listeners.
        If either the database or websocket listeners fail to be notified, it gets re-queued.
        If it partially fails, only the part that failed (db or ws) will be retried.

        :param stop_event asyncio.Event to signal graceful shutdown
        :param queue asyncio.Queue from which events will be received (and re-posted to if failed)
        """
        # TODO: Implement debounce
        try:
            while not stop_event.is_set():
                event = await queue.get()
                if stop_event.is_set():
                    return

                # attempt to notify listeners, regardless of whether it happens, set notified to true
                # websockets like this are "best-effort"
                if not event.ws_notified:
                    await AlertBackend.notify_listeners(event)
                    event.ws_notified = True

                # attempt to insert it into db, if it fails, requeue
                # database like this is not "best-effort"
                if not event.db_notified and not alert_operations.insert_alert(event):
                    await queue.put(event)
                else:
                    event.db_notified = True

        except Exception as e:
            print(f"[ERROR][FACTS]registered exception e='{str(e)}'")

    @staticmethod
    def spawn_log_stream(data_queue: janus.SyncQueue, signal_queue: janus.SyncQueue, finished: threading.Event) -> Coroutine:
        return asyncio.to_thread(lambda: alert_operations.get_alert_stream(data_queue, signal_queue, finished))


    def load_rule(self,
                    rule_id: int,
                    name: str,
                    requires_ack: bool,
                    severity: AlertSeverity,
                    target_item: int,
                    reduce_logic: AlertReduceLogic,
                    predicates: list[tuple[AlertPredicateOperation, Any, Any, str]],
                    data_source: Literal["facts", "syslog"],
                ):
        """
        Creates a new rule
        :param rule_id database rule id
        :param name display name of the rule
        :param requires_ack whether the alert requires to be acked before it can be dismissed
        :param severity AlertSeverity to be triggered upon positive evaluation of the rule
        :param target_item target device or group to which the rule will be applied to
        :param reduce_logic boolean operation that will be applied to multi-predicate rules
        :param data_source source from which to extract data
        :param predicates list of tuples of predicates to be evaluated
        """
        rule = AlertRule(rule_id, name, requires_ack, severity, target_item, reduce_logic, predicates)
        self.rules[rule_id] = rule
        match data_source:
            case "facts":
                self.__instance.facts_rules[rule_id] = rule
                return

            case "syslog":
                self.__instance.syslog_rules[rule_id] = rule
                return

            case _:
                # noinspection PyUnreachableCode
                raise Exception("Unhandled data source")

    # noinspection PyUnreachableCode
    def load_from_json(self, rule_id: int, name: str, requires_ack: bool, definition: dict):
        """
        Loads a single rule from a json dictionary, as gotten from the database column rule_definition.
        If the rule is malformed, or has missing parameters, an error log message will be issued, and it will be skipped.

        :param rule_id database rule id
        :param name display name of the rule
        :param requires_ack whether the dismissal of this alert requires manual ack
        :param definition dict holding rule definition as per the schema found at alert-definition.json
        """
        reduce_logic = AlertReduceLogic.from_str(definition.get("reduce-logic", None))
        severity     = AlertSeverity.from_str(definition.get("severity", None))
        target_item = definition.get("target", None)
        data_source = definition.get("source", None)

        AlertBackend().facts_rules = {}
        AlertBackend().syslog_rules = {}

        if name is None:
            chars = string.ascii_letters + string.digits
            name = "rule_"+''.join(random.choices(chars, k=12))
            print(f"[WARN ][ALERTS][LOADS]Unnamed rule found..., adding random name = {name}")

        if severity is None:
            print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' contains invalid severity, skipping...")
            return

        if reduce_logic is None:
            print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' contains invalid reduce_logic, skipping...")
            return

        if target_item is None:
            print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' contains invalid target_item, skipping...")
            return

        if data_source is None:
            print(f"[ERROR][ALERTS][LOADS]Named rule = '{name}' contains invalid data_source, skipping...")
            return

        predicates: list[tuple[AlertPredicateOperation, Any, Any, str]] = []
        for predicate in definition["predicates"]:
            left        = predicate["left"]
            right       = predicate["right"]
            left_const  = (not isinstance(left, str)) or "&" not in left
            right_const = (not isinstance(right, str)) or "&" not in right
            op          = AlertPredicateOperation[predicate["op"].upper()]
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

        self.load_rule(rule_id, name, requires_ack, severity, target_item, reduce_logic, predicates, data_source)
