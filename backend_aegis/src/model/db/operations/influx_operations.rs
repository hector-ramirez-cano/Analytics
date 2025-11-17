use influxdb2::{api::query::FluxRecord, models::ast::{Dialect, dialect::Annotations}};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InfluxFilter {
    pub start: String,
    pub metric: String,
    #[serde(rename = "device-id")]
    pub device_id: String,
    #[serde(rename = "aggregate-interval")]
    pub aggregate_interval: String,
}

impl InfluxFilter {
    pub fn from_json(json: &serde_json::Value) -> Option<Self> {
        let start = json.get("start")?.as_str()?.to_string();
        let metric = json.get("metric")?.as_str()?.to_string();
        let device_id = json.get("device-id")?.as_i64()?.to_string();
        let aggregate_interval = json.get("aggregate-interval")?.as_str()?.to_string();

        Some(Self {
            start,
            metric,
            device_id,
            aggregate_interval,
        })
    }

    pub fn to_dict(&self) -> HashMap<String, String> {
        let mut map = HashMap::new();
        map.insert("start".into(), self.start.clone());
        map.insert("metric".into(), self.metric.clone());
        map.insert("device_id".into(), self.device_id.clone());
        map.insert("aggregate_interval".into(), self.aggregate_interval.clone());
        map
    }
}


pub async fn get_metric_range(influx_client : &influxdb2::Client, influx_filter: &InfluxFilter) -> serde_json::Value {
    let influx_script = format!(
        r#"
        minData = from(bucket: "analytics")
            |> range(start: {})
            |> filter(fn: (r) => r["_measurement"] == "metrics")
            |> filter(fn: (r) => r["_field"] == "{}")
            |> filter(fn: (r) => r["device_id"] == "{}")
            |> min()

        maxData = from(bucket: "analytics")
            |> range(start: {})
            |> filter(fn: (r) => r["_measurement"] == "metrics")
            |> filter(fn: (r) => r["_field"] == "{}")
            |> filter(fn: (r) => r["device_id"] == "{}")
            |> max()

        union(tables: [minData, maxData])
        "#,
        influx_filter.start,
        influx_filter.metric,
        influx_filter.device_id,
        influx_filter.start,
        influx_filter.metric,
        influx_filter.device_id
    );

    let result = execute_query(influx_client, influx_script).await;

    serde_json::json!({
        "min-x": result.get(0).and_then(|f| f.get("_value")).unwrap_or(&serde_json::json!(0)),
        "min-y": result.get(1).and_then(|f| f.get("_value")).unwrap_or(&serde_json::json!(0)),
    })
}

pub async fn get_metric_data(influx_client : &influxdb2::Client, influx_filter: &InfluxFilter ) -> serde_json::Value {
    let query = format!(
        r#"
        from(bucket: "analytics")
            |> range(start: {})
            |> filter(fn: (r) => r["_measurement"] == "metrics")
            |> filter(fn: (r) => r["_field"] == "{}")
            |> filter(fn: (r) => r["device_id"] == "{}")
            |> aggregateWindow(every: {}, fn: mean, createEmpty: false)
            |> yield(name: "mean")
        "#,
        influx_filter.start,
        influx_filter.metric,
        influx_filter.device_id,
        influx_filter.aggregate_interval
    );

    let data_range = get_metric_range(influx_client, influx_filter).await;
    let data = execute_query(influx_client, query).await;

    let mut data_map = Vec::with_capacity(data.len());
    for object in data {
        data_map.push(serde_json::json!({
            "time": object.get("_time"),
            "value": object.get("_value")
        }));
    }

    let mut result = serde_json::Map::new();
    result.insert("range".to_owned(), data_range);
    result.insert("data".to_owned() , serde_json::json!(data_map));

    serde_json::Value::Object(result)
}

fn flux_value_to_json(fv: &influxdb2_structmap::value::Value) -> serde_json::Value {
    match fv {
        influxdb2_structmap::value::Value::Unknown => serde_json::Value::Null,
        influxdb2_structmap::value::Value::String(v) => serde_json::Value::String(v.clone()),
        influxdb2_structmap::value::Value::Double(v) => serde_json::json!(v.0),
        influxdb2_structmap::value::Value::Bool(v) => serde_json::Value::Bool(*v),
        influxdb2_structmap::value::Value::Long(v) => serde_json::json!(v),
        influxdb2_structmap::value::Value::UnsignedLong(v) => serde_json::json!(v),
        influxdb2_structmap::value::Value::Duration(v) => serde_json::json!(v.to_string()),
        influxdb2_structmap::value::Value::Base64Binary(_) => serde_json::json!(String::from("Unsupported")),
        influxdb2_structmap::value::Value::TimeRFC(v) => serde_json::json!(v.timestamp())
    }
}

pub fn flux_records_to_vec(records: Vec<FluxRecord>) -> Vec<serde_json::Value> {
    records
        .into_iter()
        .map(|r| {
            let mut obj = serde_json::Map::new();
            for (k, v) in r.values.iter() {
                let json_val = flux_value_to_json(v);
                obj.insert(k.clone(), json_val);
            }
            serde_json::Value::Object(obj)
        })
        .collect()
}


async fn execute_query(influx_client : &influxdb2::Client, influx_script: String) -> Vec<serde_json::Value> {
    let query = influxdb2::models::Query {
        query: influx_script.to_string(),
        dialect: Some(Dialect {
            header: Some(true),
            delimiter: Some(",".into()),
            annotations: vec![Annotations::Group, Annotations::Datatype],
            comment_prefix: None,
            date_time_format: None,
        }),
        ..Default::default()
    };
    
    let response = match influx_client.query_raw(Some(query)).await {
        Ok(r) => r,
        Err(e) => {
            log::error!("[ERROR][INFLUX] Failed to read data from Influx Database with error = '{e}'");
            return vec![serde_json::Value::Null]
        }
    };
    
    flux_records_to_vec(response)
}