from dataclasses import dataclass, field
from typing import Optional, Dict, Any

@dataclass
class Device:
    device_id: int
    device_name: Optional[str]
    position_x: float
    position_y: float
    management_hostname: str
    requested_metadata: list
    metadata: Dict[str, Any] = field(default_factory=dict)


    @staticmethod
    def find_by_management_hostname(devices: list, management_hostname :str) -> Optional["Device"]:
        for device in devices:
            if device.management_hostname == management_hostname:
                return device

        return None

    def to_dict(self):
        return {
            "id": self.device_id,
            "name": self.device_name,
            "coordinates": [self.position_x, self.position_y],
            "management-hostname": self.management_hostname,
            "metadata": self.metadata,
        }

