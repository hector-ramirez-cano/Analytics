from enum import Enum

from backend.model.ansible_status import AnsibleStatus


class DeviceState(Enum):
    SKIPPED   = 0,
    REACHABLE = 1,
    DARK      = 2,

    UNKNOWN = -1

class DeviceStatus:
    def __init__(self, ansible_status : AnsibleStatus = AnsibleStatus.UNKNOWN, msg : str =""):
        self.ansible_status = ansible_status
        self.msg = msg


    def __eq__(self, other):
        if isinstance(other, DeviceState):
            return self.ansible_status == other

        if isinstance(other, DeviceStatus):
            return self.ansible_status == other.ansible_status

        return False

    def __str__(self):
        return self.ansible_status.name + ", " + self.msg

    def to_json_str(self):
        return { "ansible_status" : self.ansible_status.name, "msg": self.msg }