from typing import Generator

from model.db.pools import influx_db_query_api

class InfluxFilter:
    def __init__(self,
        start : str,
        metric: str,
        device_id: str, # represented as a string in influxDB
        aggregate_interval: str
    ):
        self.start = start
        self.metric = metric
        self.device_id = str(device_id)
        self.aggregate_interval = aggregate_interval

    @staticmethod
    def from_json(json: dict) -> "InfluxFilter":
        start = json.get("start")
        metric = json.get("metric")
        device_id = json.get("device-id")
        aggregate_interval = json.get("aggregate-interval")

        if None in (start, metric, device_id, aggregate_interval):
            return None

        return InfluxFilter(start, metric, device_id, aggregate_interval)

    def to_dict(self) -> dict:
        return {
            "start": self.start,
            "metric": self.metric,
            "device_id": self.device_id,
            "aggregate_interval": self.aggregate_interval,
        }

def get_metric_range(influx_filter: InfluxFilter) -> dict:
    params = influx_filter.to_dict()
    query = f'''
    minData = from(bucket: "analytics")
        |> range(start: {params["start"]})
        |> filter(fn: (r) => r["_measurement"] == "metrics")
        |> filter(fn: (r) => r["_field"] == "{params["metric"]}")
        |> filter(fn: (r) => r["device_id"] == "{params["device_id"]}")
        |> min()

    maxData = from(bucket: "analytics")
        |> range(start: {params["start"]})
        |> filter(fn: (r) => r["_measurement"] == "metrics")
        |> filter(fn: (r) => r["_field"] == "{params["metric"]}")
        |> filter(fn: (r) => r["device_id"] == "{params["device_id"]}")
        |> max()

    union(tables: [minData, maxData])
    '''
    query_api = influx_db_query_api()
    result = query_api.query(query=query, params=params)
    for table in result:

        return {
            "min-y": table.records[0].get_value(),
            "max-y": table.records[1].get_value(),
        }


def get_metric_data(influx_filter: InfluxFilter) -> dict:
    # 2025/oct/23 - Unsafe, apparently the client still doesn't support param queries
    # TODO: Implement param queries when the client implements it

    params = influx_filter.to_dict()
    query = f'''
    from(bucket: "analytics")
        |> range(start: {params["start"]})
        |> filter(fn: (r) => r["_measurement"] == "metrics")
        |> filter(fn: (r) => r["_field"] == "{params["metric"]}")
        |> filter(fn: (r) => r["device_id"] == "{params["device_id"]}")
        |> aggregateWindow(every: {params["aggregate_interval"]}, fn: mean, createEmpty: true)
        |> yield(name: "mean")
    '''
    query_api = influx_db_query_api()
    result = query_api.query(query=query, params=params)
    data = [
        {"time": record.get_time().timestamp(), "value": record.get_value()}
        for table in result for record in table.records
    ]
    data_range = get_metric_range(influx_filter)
    return {
        "data": data,
        "range": data_range
    }
