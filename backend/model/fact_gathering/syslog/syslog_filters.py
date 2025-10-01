from datetime import datetime
from typing import Set

from backend.model.fact_gathering.syslog.syslog_facility import SyslogFacility
from backend.model.fact_gathering.syslog.syslog_severity import SyslogSeverity


class SyslogFilters:
    def __init__(self,
        start_time: datetime,
        end_time: datetime,
        facilities: Set[SyslogFacility],
        severities: Set[SyslogSeverity],
        offset : int
    ):
        self.facilities = facilities
        self.severities = severities
        self.start_time = start_time
        self.end_time   = end_time
        self.offset     = offset


    @staticmethod
    def from_json(json: dict) -> "SyslogFilters":
        start_time = datetime.fromtimestamp(float(json["start"]))
        end_time = datetime.fromtimestamp(float(json["end"]))
        facilities = set(SyslogFacility.from_json(json))
        severities = set(SyslogSeverity.from_json(json))
        offset = json.get("offset", 0)

        return SyslogFilters(start_time, end_time, facilities, severities, offset)


    def has_set_filter(self, item) -> bool:
        for filter_set in [self.facilities, self.severities]:
            if filter_set.__contains__(item):
                return True

        return False


    def set_has_filters(self, set_type) -> bool:
        if set_type == SyslogFacility:
            return len(SyslogFacility) != len(self.facilities)

        if set_type == SyslogSeverity:
            return len(SyslogSeverity) != len(self.severities)

        else:
            return False


    def get_sql_where_clause(self) -> tuple[str, tuple]:
        clause = "ReceivedAt BETWEEN ? AND ? "
        params = [ self.start_time, self.end_time ]

        if self.set_has_filters(SyslogFacility):
            clause = clause + f"AND Facility IN ( {','.join(['?'] * len(self.facilities))} )"
            params.extend([int(facility.value) for facility in self.facilities])

        if self.set_has_filters(SyslogSeverity):
            clause = clause + f"AND Priority IN ( {','.join(['?'] * len(self.severities))} ) "
            params.extend([int(severity.value) for severity in self.severities])

        if self.offset > 0:
            clause = clause + "LIMIT -1 OFFSET ? "
            params.append(self.offset)

        return clause, tuple(params)
