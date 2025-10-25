from enum import Enum

class AnsibleStatus(Enum):
    SKIPPED   = 0
    REACHABLE = 1
    DARK      = 2

    UNKNOWN = -1

    def __str__(self):
        match self:
            case AnsibleStatus.SKIPPED:
                return "SKIPPED"

            case AnsibleStatus.REACHABLE:
                return "REACHABLE"

            case AnsibleStatus.DARK:
                return "DARK"

            case _:
                return "UNKNOWN"
