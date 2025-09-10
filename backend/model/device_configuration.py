from dataclasses import dataclass


@dataclass
class DeviceConfiguration:
    data_sources: set[str]
    available_values: set[str]
    requested_metadata: set[str]
    requested_metrics: set[str]

    def to_dict(self) -> dict:
        contents = {
            "available-values": list(self.available_values),
            "requested-metadata": list(self.requested_metadata),
            "requested-metrics": list(self.requested_metrics),
            "data-sources": list(self.data_sources),
        }

        print(contents)
        return contents


