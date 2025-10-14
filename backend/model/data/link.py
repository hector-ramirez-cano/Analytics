from dataclasses import dataclass


@dataclass
class Link:
    def __init__(self,
        link_id : int,
        side_a_id : int,
        side_b_id : int,
        side_a_iface : str,
        side_b_iface: str,
        link_type: str,
        link_subtype: str,
    ):
        self.link_id = link_id
        self.side_a_id = side_a_id
        self.side_b_id = side_b_id
        self.side_a_iface = side_a_iface
        self.side_b_iface = side_b_iface
        self.link_type = link_type
        self.link_subtype = link_subtype

    def to_dict(self):
        return {
            "id": self.link_id,
            "side-a": self.side_a_id,
            "side-b": self.side_b_id,
            "link-type": str(self.link_type),
            "side-a-iface": self.side_a_iface,
            "side-b-iface": self.side_b_iface,
        }

    @staticmethod
    def from_dict(d: dict) -> "Link":
        return Link(
            link_id=d["id"],
            side_a_id=d["side-a"],
            side_b_id=d["side-b"],
            side_a_iface=d["side-a-iface"],
            side_b_iface=d["side-b-iface"],
            link_type=d["link-type"],
            link_subtype=d.get("link-subtype", None)
        )