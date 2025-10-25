from enum import Enum

class IcmpStatus (Enum):
    REACHABLE             = 0
    UNREACHABLE           = 1
    TIMEOUT               = 2
    HOST_NOT_FOUND        = 3
    NAME_RESOLUTION_ERROR = 4

    UNKNOWN = -1

    def __str__(self):
        match self:
            case IcmpStatus.REACHABLE:
                return "REACHABLE"

            case IcmpStatus.UNREACHABLE:
                return "UNREACHABLE"

            case IcmpStatus.TIMEOUT:
                return "TIMEOUT"

            case IcmpStatus.HOST_NOT_FOUND:
                return "HOST_NOT_FOUND"

            case IcmpStatus.NAME_RESOLUTION_ERROR:
                return "NAME_RESOLUTION_ERROR"

            case _:
                return "UNKNOWN"