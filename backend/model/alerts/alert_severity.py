from enum import Enum


class AlertSeverity(Enum):
    emergency = "emergency"
    alert     = "alert"
    critical  = "critical"
    error     = "error"
    warning   = "warning"
    notice    = "notice"
    info      = "info"
    debug     = "debug"
    unknown   = "unknown"

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