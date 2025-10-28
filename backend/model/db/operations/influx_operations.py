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
        """Creates a new InfluxFilter instance based off a dictionary

        Args:
            json (dict): dictionary, typically parsed from a json, with the definition

        Returns:
            InfluxFilter | None: Instance, or None if any component is missing
        """
        start = json.get("start")
        metric = json.get("metric")
        device_id = json.get("device-id")
        aggregate_interval = json.get("aggregate-interval")

        if None in (start, metric, device_id, aggregate_interval):
            return None

        return InfluxFilter(start, metric, device_id, aggregate_interval)

    def to_dict(self) -> dict:
        """Converts the instance into dict representation

        Returns:
            dict: dict representation
        """
        return {
            "start": self.start,
            "metric": self.metric,
            "device_id": self.device_id,
            "aggregate_interval": self.aggregate_interval,
        }

def get_metric_range(influx_filter: InfluxFilter) -> dict:
    """Gets the range of a metric, in terms of min and max

    Args:
        influx_filter (InfluxFilter): Filter to be applied, to which the range will be queried

    Returns:
        dict: dict containing both "min-y" and "max-y" as results
    """
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
    """Queries the InfluxDB for metrics in a given timeframe, defined by the influxFilter instance

    Args:
        influx_filter (InfluxFilter): Filter to be applied for data

    Returns:
        dict: data series as given by the influxDB, following {"range": [range], "data": [{"time": [timestamp], "value": [value], ...}]}
    """
    # TODO: Implement param queries when the client implements it
    # 2025/oct/23 - Unsafe, apparently the client still doesn't support param queries

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
