from dataclasses import dataclass


@dataclass
class DeviceConfiguration:
    data_sources: set
    available_values: set[str]
    requested_metadata: set[str]
    requested_metrics: set[str]

    def to_dict(self) -> dict:
        return {
            "available-values": self.available_values,
            "requested-metadata": self.requested_metadata,
            "requested-metrics": self.requested_metrics,
        }


