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
