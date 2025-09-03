from enum import Enum

class AnsibleStatus(Enum):
    SKIPPED   = 0,
    REACHABLE = 1,
    DARK      = 2,

    UNKNOWN = -1