from enum import Enum

class IcmpStatus (Enum):
    REACHABLE             = 0
    UNREACHABLE           = 1
    TIMEOUT               = 2
    HOST_NOT_FOUND        = 3
    NAME_RESOLUTION_ERROR = 4

    UNKNOWN = -1