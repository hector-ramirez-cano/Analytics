from datetime import datetime
from typing import Set

from model.syslog.syslog_facility import SyslogFacility
from model.syslog.syslog_severity import SyslogSeverity


class SyslogFilters:
    def __init__(self,
        start_time: datetime,
        end_time: datetime,
        facilities: Set[SyslogFacility],
        severities: Set[SyslogSeverity],
        offset : int,
        origin: str,
        pid: str,
        message: str,
    ):
        self.facilities = facilities
        self.severities = severities
        self.start_time = start_time
        self.end_time   = end_time
        self.offset     = offset
        self.origin     = origin
        self.pid        = pid
        self.message    = message


    @staticmethod
    def from_json(json: dict) -> "SyslogFilters":
        start_time = datetime.fromtimestamp(float(json["start"]))
        end_time = datetime.fromtimestamp(float(json["end"]))
        facilities = set(SyslogFacility.from_json(json.get("facility")))
        severities = set(SyslogSeverity.from_json(json.get("severity")))
        offset = json.get("offset", 0)
        message = json.get("message", "")
        origin = json.get("origin", "")
        pid = json.get("pid", "")

        return SyslogFilters(start_time, end_time, facilities, severities, offset, origin, pid, message)


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

    def __get_sql_query_with_orderby(self, query: str, has_match: bool) -> str:
        if not has_match:
            return query

        # ordering by this only makes sense if the query contains it, bruv
        if "rank" in query:
            return query + " ORDER BY rank "

        return query


    def __get_sql_query_with_limit_offset(self, query: str, params: list) -> str:
        clause = query
        if self.offset > 0:
            clause = clause + "LIMIT -1 OFFSET ? "
            params.append(self.offset)

        return clause


    def __get_sql_data_where_clause(self, params: list) -> str:
        clause = "se.ReceivedAt BETWEEN ? AND ? "
        params.extend([self.start_time, self.end_time])

        if self.set_has_filters(SyslogFacility):
            clause = clause + f"AND se.Facility IN ( {','.join(['?'] * len(self.facilities))} )"
            params.extend([int(facility.value) for facility in self.facilities])

        if self.set_has_filters(SyslogSeverity):
            clause = clause + f"AND se.Priority IN ( {','.join(['?'] * len(self.severities))} ) "
            params.extend([int(severity.value) for severity in self.severities])

        if len(self.origin) != 0:
            clause = clause + f"AND se.FromHost LIKE ? "
            # if the user defines a pattern, use the user pattern, append as is
            if any(c in self.origin for c in ("%", "_")):
                params.append(self.origin)
            else:
                # no user supplied pattern, we add our own for more convenient search
                params.append(f"%{self.origin}%")


        if len(self.pid) != 0:
            clause = clause + f"AND se.ProcessID LIKE ? "
            if any(c in self.origin for c in ("%", "_")):
                params.append(self.pid)
            else:
            # no user supplied pattern, we add our own for more convenient search
                params.append(f"%{self.pid}%")

        # No self.message, as that leverages FTS5

        return clause


    def __has_match(self):
        return not (len(self.origin) == len(self.pid) == len(self.message) == 0)

    def __get_single_sql_select_query(self, database : str, params: list, target: str, has_match: bool) -> str:

        if not has_match:
            # ReceivedBetween ? AND ? [AND in(...) AND in(...)]
            where_clause = self.__get_sql_data_where_clause(params)
            return f"SELECT {target} FROM {database}.SystemEvents se WHERE {where_clause}"

        # extend with first param
        if len(self.message) > 0:
            params.append(self.message)

        # extend with where clause
        where_clause = self.__get_sql_data_where_clause(params)

        # use bm25 only if select is not a count
        full_target = target
        if "count" not in target:
            full_target = full_target + ", bm25(SystemEvents_FTS) AS rank"

        clause = f"""
            SELECT {full_target} 
            FROM {database}.SystemEvents_FTS fts
            JOIN {database}.SystemEvents se ON se.ID = fts.rowid
            WHERE SystemEvents_FTS MATCH ?
            AND {where_clause}
        """

        return clause


    def __get_sql_select_query(self, databases: list[str], params: list, target: str, has_match: bool) -> str:
        return " UNION ALL ".join([self.__get_single_sql_select_query(database, params, target, has_match) for database in databases])


    def get_sql_query(self, target: str, databases: list[str]) -> tuple[str, tuple]:
        params = []
        has_match = self.__has_match()

        # get **combined** SELECT query depending on whether it has matches
        query = self.__get_sql_select_query(databases, params, target=target, has_match=has_match)


        # Sum across shards, if we're calculating a sum
        if "count" in target:
            query = f"SELECT SUM(count) AS total FROM ({query})"

        else:
            # extend with order by, if it has match, and it's not count
            query = self.__get_sql_query_with_orderby(query, has_match=has_match)

            # extend with limits+offset if it has offset
            query = self.__get_sql_query_with_limit_offset(query, params)

        return query, params