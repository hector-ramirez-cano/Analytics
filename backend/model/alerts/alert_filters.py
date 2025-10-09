from datetime import datetime

from backend.model.alerts.alert_severity import AlertSeverity


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
        offset: int
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

        if ack_start_time is not None and ack_end_time is not None:
            ack_start_time = datetime.fromtimestamp(float(ack_start_time))
            ack_end_time = datetime.fromtimestamp(float(ack_end_time  ))

        return AlertFilters(
            start_time, end_time, alert_id,
            ack_start_time, ack_end_time, severity,
            message, ack_actor, target_id, offset
        )

    def __get_sql_query_with_limit_offset(self, query: str, params: list) -> str:
        clause = query
        if self is not None and isinstance(self.offset, int) and self.offset > 0:
            clause = clause + "LIMIT -1 OFFSET %s "
            params.append(self.offset)

        return clause


    def __get_sql_data_where_clause(self, params: list) -> str:
        clause = "alert_time BETWEEN %s AND %s "
        params.extend([self.start_time, self.end_time])

        if self.set_has_filters(AlertFilters):
            clause = clause + f"AND severity IN ( {','.join(['%s'] * len(self.severities))} )"
            params.extend([severity.value for severity in self.severities])

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
        query = self.__get_sql_query_with_limit_offset(query, params)

        return query, params

    def set_has_filters(self, set_type) -> bool:

        if set_type == AlertSeverity:
            return len(AlertSeverity) != len(self.severities)

        else:
            return False