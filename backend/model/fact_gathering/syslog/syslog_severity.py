from enum import Enum
from typing import override


class SyslogSeverity(Enum):
    emerg   = 0
    alert   = 1
    crit    = 2
    err     = 3
    warning = 4
    notice  = 5
    info    = 6
    debug   = 7

    @staticmethod
    def values() -> list["SyslogSeverity"]:
        return [name.value for name in SyslogSeverity]


    @staticmethod
    def from_json(json: dict) -> list["SyslogSeverity"]:
        return [SyslogSeverity[severity] for severity in json["severity"]]


    def __str__(self) -> str:
        return self.name