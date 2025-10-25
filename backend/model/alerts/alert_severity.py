from enum import Enum


class AlertSeverity(Enum):
    EMERGENCY = "emergency"
    ALERT     = "alert"
    CRITICAL  = "critical"
    ERROR     = "error"
    WARNING   = "warning"
    NOTICE    = "notice"
    INFO      = "info"
    DEBUG     = "debug"
    UNKNOWN   = "unknown"

    @staticmethod
    def from_str(value: str) -> "AlertSeverity":
        try:
            return AlertSeverity(value)
        except ValueError:
            return None


    @staticmethod
    def from_json(json: dict) -> list["AlertSeverity"]:
        return [AlertSeverity[severity] for severity in json]

    def __str__(self):
        return self.value
