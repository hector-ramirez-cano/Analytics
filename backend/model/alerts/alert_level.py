from enum import Enum


class AlertLevel(Enum):
    emergency = "emergency"
    alert     = "alert"
    critical  = "critical"
    error     = "error"
    warning   = "warning"
    notice    = "notice"
    info      = "info"
    debug     =  "debug"

    @staticmethod
    def from_string(value: str) -> "AlertLevel":
        try:
            return AlertLevel(value)
        except ValueError:
            return None