from datetime import datetime

from model.alerts.alert_severity import AlertSeverity

class AlertFilters:
    def __init__(self,
        start_time: datetime,
        end_time: datetime,
        alert_id: int,
        ack_start_time : datetime,
        ack_end_time : datetime,
        severity: set[AlertSeverity],
        message: str,
        ack_actor: int,
        target_id: int,
        offset: int,
        requires_ack: bool,
    ):
        self.start_time = start_time
        self.end_time = end_time
        self.alert_id = alert_id
        self.ack_start_time = ack_start_time
        self.ack_end_time = ack_end_time
        self.severities = severity
        self.message = message
        self.ack_actor = ack_actor
        self.target_id = target_id
        self.offset = offset
        self.requires_ack = requires_ack

    @staticmethod
    def from_json(json: dict) -> "AlertFilters":
        start_time     = datetime.fromtimestamp(float(json["start"]))
        end_time       = datetime.fromtimestamp(float(json["end"]))
        ack_start_time = json.get("ack-start", None)
        ack_end_time   = json.get("ack-end", None)
        alert_id       = json.get("id")
        severity       = set(AlertSeverity.from_json(json.get("severity", set())))
        message        = json.get("message")
        ack_actor      = json.get("ack-actor")
        target_id      = json.get("target-id")
        offset         = json.get("offset")
        requires_ack   = json.get("requires-ack")

        if ack_start_time is not None and ack_end_time is not None:
            ack_start_time = datetime.fromtimestamp(float(ack_start_time))
            ack_end_time = datetime.fromtimestamp(float(ack_end_time  ))

        return AlertFilters(
            start_time, end_time, alert_id,
            ack_start_time, ack_end_time, severity,
            message, ack_actor, target_id, offset,
            requires_ack
        )

    def __get_sql_query_with_limit_offset(self, query: str, params: list, target: str) -> str:
        clause = query
        if self is not None and isinstance(self.offset, int) and self.offset > 0 and not "count" in target.lower():
            clause = clause + " OFFSET %s "
            params.append(self.offset)

        return clause


    def __get_sql_data_where_clause(self, params: list) -> str:
        clause = "alert_time BETWEEN %s AND %s "
        params.extend([self.start_time, self.end_time])

        if self.set_has_filters(AlertSeverity):
            clause = clause + "AND severity = ANY ( %s )"
            params.append( '{' +  ','.join([str(severity) for severity in self.severities]) + '}' )

        if self.ack_start_time is not None and self.ack_end_time is not None:
            clause = clause + " AND ack_time BETWEEN %s AND %s "
            params.extend([self.ack_start_time, self.ack_end_time])

        if self.alert_id is not None:
            clause = clause + " AND alert_id = %s"
            params.append(self.alert_id)

        if self.message is not None and isinstance(self.message, str) and len(self.message) != 0:
            clause = clause + " AND message LIKE %s "
            params.append(self.message)

        if self.ack_actor is not None and isinstance(self.ack_actor, str) and len(self.ack_actor) != 0:
            clause = clause + " AND ack_actor LIKE %s "
            params.append(self.ack_actor)

        if self.target_id is not None and isinstance(self.target_id, int):
            clause = clause + " AND target_id = %s "
            params.append(self.target_id)

        if self.requires_ack is not None and isinstance(self.requires_ack, bool):
            clause = clause + " AND requires_ack = %s "
            params.append(self.requires_ack)

        return clause


    def __get_sql_select_query(self, params: list, target: str) -> str:

        # ReceivedBetween %s AND %s [AND in(...) AND in(...)]
        where_clause = self.__get_sql_data_where_clause(params)
        return f"SELECT {target} FROM Analytics.alerts WHERE {where_clause}"


    def get_sql_query(self, target: str,) -> tuple[str, tuple]:
        params = []

        # get **combined** SELECT+WHERE query
        query = self.__get_sql_select_query(params, target=target)

        # extend with limits+offset if it has offset
        query = self.__get_sql_query_with_limit_offset(query, params, target=target)

        return query, params

    def set_has_filters(self, set_type) -> bool:

        if set_type == AlertSeverity:
            return len(AlertSeverity) != len(self.severities)

        else:
            return False
