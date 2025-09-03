from dataclasses import dataclass


@dataclass
class DeviceConfiguration:
    data_sources: set
    available_values: set[str]
    requested_metadata: list

