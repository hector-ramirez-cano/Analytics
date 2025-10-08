from dataclasses import dataclass, field
from typing import Optional, Dict, Any

from backend.model.alerts.alert_rules import AlertRule
from backend.model.device_configuration import DeviceConfiguration
from backend.model.device_state import DeviceStatus


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

    def to_dict(self):
        print({
            "id": self.device_id,
            "name": self.device_name,
            "coordinates": [self.position_x, self.position_y],
            "geocoordinates": [self.latitude, self.longitude],
            "management-hostname": self.management_hostname,
            # "status": self.state.to_json_str(),
            # "metadata": self.metadata,
            "configuration": self.configuration.to_dict()
        })
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
