import datetime
import json
from dataclasses import dataclass

from model.alerts.alert_severity import AlertSeverity

#TODO: ADD ACKACTOR
@dataclass
class AlertEvent:
    def __init__(self, requires_ack: bool, severity: AlertSeverity, message: str, target_id: int, ack_time: datetime.datetime):
        self.alert_id = -1
        self.alert_time = datetime.datetime.now()
        self.ack_time = ack_time
        self.requires_ack = requires_ack
        self.severity = severity
        self.message = message
        self.target_id = target_id
        self.ws_notified = False
        self.db_notified = False
        self.acked = not requires_ack

    def to_dict(self) -> dict:
        alert_time = self.alert_time
        ack_time = self.ack_time
        if self.alert_time is not None:
            alert_time = alert_time.timestamp()

        if self.ack_time is not None:
            ack_time = self.ack_time.timestamp()

        return  {
            "alert-id": self.alert_id,
            "alert-time": alert_time,
            "ack-time": ack_time,
            "requires-ack": self.requires_ack,
            "severity": self.severity,
            "message": self.message,
            "target-id": self.target_id,
            "acked": self.acked,
        }

    def __str__(self):
        as_dict = self.to_dict()
        as_dict["severity"] = str(as_dict["severity"])
        return json.dumps(as_dict)