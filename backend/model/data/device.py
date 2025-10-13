from dataclasses import dataclass, field
from typing import Optional, Dict, Any

from model.alerts.alert_rules import AlertRule
from model.device_configuration import DeviceConfiguration
from model.device_state import DeviceStatus


@dataclass
class Device:
    device_id: int
    device_name: Optional[str]
    position_x: float
    position_y: float
    latitude: float
    longitude: float
    management_hostname: str
    configuration: DeviceConfiguration

    state: DeviceStatus = field(default_factory=DeviceStatus)
    metadata: Dict[str, Any] = field(default_factory=dict)



    @staticmethod
    def find_by_management_hostname(devices: dict, management_hostname :str) -> Optional["Device"]:
        for device_id in devices:
            if devices[device_id].management_hostname == management_hostname:
                return devices[device_id]

        return None

    def to_json(self):
        return {
            "id": self.device_id,
            "name": self.device_name,
            "coordinates": [self.position_x, self.position_y],
            "geocoordinates": [self.latitude, self.longitude],
            "management-hostname": self.management_hostname,
            # "status": self.state.to_json_str(),
            # "metadata": self.metadata,
            "configuration": self.configuration.to_dict()
        }

    def eval_rule(self, rule: AlertRule, d: dict, _get_item_fn) -> tuple[bool, tuple["Device"]]:
        return rule.eval(d.get(self.management_hostname, {})), (self,)


    @staticmethod
    def from_dict(d: dict):
        return Device(
            device_id=d["id"],
            device_name=d["name"],
            position_x=d["coordinates"][0],
            position_y=d["coordinates"][1],
            latitude=d["geocoordinates"][0],
            longitude=d["geocoordinates"][1],
            management_hostname=d["management-hostname"],
            configuration=DeviceConfiguration.from_dict(d)
        )
