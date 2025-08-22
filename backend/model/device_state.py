from enum import Enum

class DeviceState(Enum):
    SKIPPED   = 0,
    REACHABLE = 1,
    DARK      = 2,

    UNKNOWN = -1

class DeviceStatus:
    def __init__(self, state : DeviceState = DeviceState.UNKNOWN, msg : str =""):
        self.state = state
        self.msg = msg


    def __eq__(self, other):
        if isinstance(other, DeviceState):
            return self.state == other

        if isinstance(other, DeviceStatus):
            return self.state == other.state

        return False

    def __str__(self):
        return self.state.name + ", " + self.msg

    def to_json_str(self):
        return { "state" : self.state.name, "msg": self.msg }