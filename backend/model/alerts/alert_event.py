import datetime
import json
from dataclasses import dataclass

from backend.model.alerts.alert_severity import AlertSeverity

@dataclass
class AlertEvent:
    def __init__(self, requires_ack: bool, severity: AlertSeverity, message: str, target_id: int):
        self.alert_id = -1
        self.alert_time = datetime.datetime.now()
        self.requires_ack = requires_ack
        self.severity = severity
        self.message = message
        self.target_id = target_id
        self.ws_notified = False
        self.db_notified = False
        self.acked = not requires_ack

    def to_dict(self) -> dict:
        return  {
            "alert_id": self.alert_id,
            "alert_time": self.alert_time.timestamp(),
            "requires_ack": self.requires_ack,
            "severity": self.severity,
            "message": self.message,
            "target_id": self.target_id,
            "acked": self.acked,
        }

    def __str__(self):
        as_dict = self.to_dict()
        as_dict["severity"] = str(as_dict["severity"])
        return json.dumps(as_dict)