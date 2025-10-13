from enum import Enum

from model.Icmp_status import IcmpStatus
from model.ansible_status import AnsibleStatus
from model.snmp_status import SnmpStatus


class DeviceState(Enum):
    SKIPPED   = 0,
    REACHABLE = 1,
    DARK      = 2,

    UNKNOWN = -1

class DeviceStatus:
    def __init__(
            self,
            ansible_status : AnsibleStatus = AnsibleStatus.UNKNOWN,
            icmp_status    : IcmpStatus = IcmpStatus.UNKNOWN,
            snmp_status    : SnmpStatus = SnmpStatus.UNKNOWN,
            msg=None
        ):
        self.ansible_status = ansible_status
        self.icmp_status = icmp_status
        self.snmp_status = snmp_status
        self.msg = msg

    @staticmethod
    def make_from_dict(status: dict) -> "DeviceStatus":
        ansible = status.get("ansible_status", {})
        icmp    = status.get("icmp_status"   , {})
        snmp    = status.get("snmp_status"   , {})

        msg = {
            "ansible": ansible.get("msg", ""),
            "icmp": icmp.get("msg", ""),
            "snmp": snmp.get("msg", "")
        }

        ansible = ansible.get("status", AnsibleStatus.UNKNOWN)
        icmp = icmp.get("status", IcmpStatus.UNKNOWN)
        snmp = snmp.get("status", SnmpStatus.UNKNOWN)

        return DeviceStatus(ansible_status=ansible, icmp_status=icmp, snmp_status=snmp, msg=msg)


    def __str__(self):
        return self.ansible_status.name + ", " + self.icmp_status.name + ", " + self.snmp_status.name + ", " + self.msg

    def to_json_str(self):
        return {
            "ansible_status" : self.ansible_status.name,
            "icmp_status" : self.icmp_status.name,
            "snmp_status": self.snmp_status.name,
            "msg": self.msg
        }