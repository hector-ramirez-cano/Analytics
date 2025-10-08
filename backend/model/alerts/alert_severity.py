from enum import Enum


class AlertSeverity(Enum):
    emergency = "emergency"
    alert     = "alert"
    critical  = "critical"
    error     = "error"
    warning   = "warning"
    notice    = "notice"
    info      = "info"
    debug     =  "debug"

    @staticmethod
    def from_str(value: str) -> "AlertSeverity":
        try:
            return AlertSeverity(value)
        except ValueError:
            return None

    def __str__(self):
        return self.value