use std::collections::HashMap;
use std::env;
use influxdb2::{api::query::FluxRecord, models::ast::{Dialect, dialect::Annotations}};
use serde::{Deserialize, Serialize};

use influxdb2::models::DataPoint;
use rocket::futures::stream;

use crate::{config::Config, model::{cache::Cache, facts::fact_gathering_backend::FactMessage}, types::{DeviceHostname, DeviceId, MetricName, MetricValue, Metrics}};

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
    let query = if influx_filter.metric.starts_with("baseline_") {
        
        let stripped = influx_filter.metric.strip_prefix("baseline_").unwrap_or_default(); 
        let mut parts = stripped.splitn(2, '_');

        let window = parts.next().unwrap_or_default(); // "15m"
        let metric = parts.next().unwrap_or_default(); // "icmp_rtt"
        format!(
            r#"
            minData = from(bucket: "baselines")
                |> range(start: {})
                |> filter(fn: (r) => r["_measurement"] == "metrics")
                |> filter(fn: (r) => r["_field"] == "{}")
                |> filter(fn: (r) => r["device_id"] == "{}")
                |> filter(fn: (r) => r["window"] == "{}")
                |> aggregateWindow(every: {}, fn: mean, createEmpty: false)
                |> min()

            maxData = from(bucket: "baselines")
                |> range(start: {})
                |> filter(fn: (r) => r["_measurement"] == "metrics")
                |> filter(fn: (r) => r["_field"] == "{}")
                |> filter(fn: (r) => r["device_id"] == "{}")
                |> filter(fn: (r) => r["window"] == "{}")
                |> aggregateWindow(every: {}, fn: mean, createEmpty: false)
                |> max()

            union(tables: [minData, maxData])
            "#,
            influx_filter.start,
            metric,
            influx_filter.device_id,
            window,
            influx_filter.aggregate_interval,
            influx_filter.start,
            metric,
            influx_filter.device_id,
            window,
            influx_filter.aggregate_interval,
        )
    } else {
        format!(
            r#"
            minData = from(bucket: "analytics")
                |> range(start: {})
                |> filter(fn: (r) => r["_measurement"] == "metrics")
                |> filter(fn: (r) => r["_field"] == "{}")
                |> filter(fn: (r) => r["device_id"] == "{}")
                |> aggregateWindow(every: {}, fn: mean, createEmpty: false)
                |> min()

            maxData = from(bucket: "analytics")
                |> range(start: {})
                |> filter(fn: (r) => r["_measurement"] == "metrics")
                |> filter(fn: (r) => r["_field"] == "{}")
                |> filter(fn: (r) => r["device_id"] == "{}")
                |> aggregateWindow(every: {}, fn: mean, createEmpty: false)
                |> max()

            union(tables: [minData, maxData])
            "#,
            influx_filter.start,
            influx_filter.metric,
            influx_filter.device_id,
            influx_filter.aggregate_interval,
            influx_filter.start,
            influx_filter.metric,
            influx_filter.device_id,
            influx_filter.aggregate_interval
        )
    };

    let result = execute_query(influx_client, query).await;

    serde_json::json!({
        "min-y": result.first().and_then(|f| f.get("_value")).unwrap_or(&serde_json::json!(0)),
        "max-y": result.get(1).and_then(|f| f.get("_value")).unwrap_or(&serde_json::json!(0)),
    })
}

pub async fn get_metric_data(influx_client : &influxdb2::Client, influx_filter: &InfluxFilter ) -> serde_json::Value {
    let query = if influx_filter.metric.starts_with("baseline_") {
        
        let stripped = influx_filter.metric.strip_prefix("baseline_").unwrap_or_default(); 
        let mut parts = stripped.splitn(2, '_');

        let window = parts.next().unwrap_or_default(); // "15m"
        let metric = parts.next().unwrap_or_default(); // "icmp_rtt"

        format!(
            r#"
            from(bucket: "baselines")
                |> range(start: {})
                |> filter(fn: (r) => r["_measurement"] == "metrics")
                |> filter(fn: (r) => r["_field"] == "{}")
                |> filter(fn: (r) => r["device_id"] == "{}")
                |> filter(fn: (r) => r["window"] == "{}")
                |> aggregateWindow(every: {}, fn: mean, createEmpty: false)
                |> yield(name: "mean")
            "#,
            influx_filter.start,
            metric,
            influx_filter.device_id,
            window,
            influx_filter.aggregate_interval
        )
    } else {
        format!(
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
        )
    };
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

pub async fn get_baseline_metrics(influx_client: &influxdb2::Client, device_hostnames: &HashMap<DeviceId, DeviceHostname>) -> Metrics {

    if device_hostnames.is_empty() {
        log::info!("[INFO ][FACTS][BASELINE] Baseline could not emit facts, as hostnames are not in cache yet...");
        return Metrics::new()
    }

    let query = r#"
        from(bucket: "baselines")
            |> range(start: -2h)
            |> last()
    "#.to_string();

    let data = execute_query(influx_client, query).await;

    let mut metrics: HashMap<DeviceHostname, HashMap<MetricName, MetricValue>> = Metrics::new();

    for point in data {
        let point = match point {
            serde_json::Value::Object(map) => map,
            _ => {
                log::warn!("[WARN ][FACTS][BASELINE] Found a non-map value while extracting baselines into facts. Value will be ignored...");
                continue;
            }
        };

        let device_id = match point.get("device_id") {
            Some (serde_json::Value::String(s)) => {
                match s.parse() {
                    Ok(id) => id,
                    Err(_) => {
                        log::warn!("[WARN ][FACTS][BASELINE] 'device_id' was found, but could not be converted into i64. Value will be ignored...");
                        continue;
                    }
                }
            },
            Some (serde_json::Value::Number(n)) => {
                match n.as_i64() {
                    Some(n) => n,
                    None => {
                        log::warn!("[WARN ][FACTS][BASELINE] 'device_id' was found to be a number, but could not be converted ino i64. Value will be ignored...");
                        continue;
                    }
                }
            },
            _ => {
                log::warn!("[WARN ][FACTS][BASELINE] 'device_id' was not found to be string/number while extracting baseline. Value will be ignored...");
                continue;
            }
        };

        let hostname = match device_hostnames.get(&device_id) {
            Some(h) => h,
            None => {
                log::warn!("[WARN ][FACTS][BASELINE] 'device_id'({device_id}) was found, but could not resolve into a device_hostname from cache. Value will be ignored...");
                continue;
            }
        };

        let field = match point.get("_field")  {
            Some(serde_json::Value::String(s)) => s,
            _ => {
                log::warn!("[WARN ][FACTS][BASELINE] '_field' wasn't found in the influx cache. Value will be ignored...");
                log::info!("                         ^ This message should be unreachable if Influx is behaving like it should.");
                continue;
            }
        };

        let window = match point.get("window") {
            Some(serde_json::Value::String(s)) => s,
            _ => {
                log::warn!("[WARN ][FACTS][BASELINE] 'window' wasn't found in the influx cache. Value will be ignored...");
                log::info!("                         ^ This message should be unreachable if Influx is behaving like it should.");
                continue;
            }
        };

        let value = match point.get("_value") {
            Some(serde_json::Value::Number(n)) => {
                match n.as_f64() {
                    Some(n) => n,
                    None => {
                        log::warn!("[WARN][FACTS][BASELINE] '_value' cannot be converted into f64. This means either it's not a number, or number is out of bounds. n='{n}'");
                        continue;
                    }
                }
            },
            _ => {
                log::warn!("[WARN ][FACTS][BASELINE] '_value' wasn't found in the influx cache. Value will be ignored...");
                log::info!("                         ^ This message should be unreachable if Influx is behaving like it should.");
                continue;
            }
        };

        let metric_name = format!("baseline_{window}_{field}");

        // Insert the entry
        metrics.entry(hostname.to_owned())
            .or_default()
            .insert(metric_name, MetricValue::Number(value.into()));
    }


    metrics
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

/// Inserts datapoints into influxdb bucket.
pub async fn update_device_analytics(influx_client : &influxdb2::Client, message : &FactMessage) {

    log::info!("[INFO ][FACTS] Updating Influx with metrics, from inside the update device analytics function");

    let bucket  = Config::instance().get::<String>("backend/controller/influx/bucket", "/");

    let bucket = match bucket {
        Ok(b) => b,
        Err(e) => {
            log::error!("[FATAL] Influx bucket isn't specified in configuration file, e='{e}'\n Expected 'backend/controller/influx/bucket' to be present");
            let cwd = env::current_dir().expect("[FATAL]Failed to get current working directory");
            log::info!("[INFO ] Current working directory was={}", cwd.display());
            log::info!("[INFO ] Current config file was={}", Config::instance().get_curr_config_path());
            panic!("[FATAL] Influx bucket isn't specified in configuration file, e='{e}'\n Expected 'backend/controller/influx/bucket' to be present");
        }
    };

    let mut points = Vec::new();

    #[cfg(debug_assertions)] {
        log::info!("[DEBUG][FACTS][INFLUX] THIS is a bucket = '{}'", &bucket);
        log::info!("[DEBUG][FACTS][INFLUX] Dear god...");
        log::info!("[DEBUG][FACTS][INFLUX] There's more...");
        log::info!("[DEBUG][FACTS][INFLUX] Nooo...");
    }


    for (device, facts) in message {
        let device_id = match Cache::instance().get_device_id(device).await { Some(v) => v, None => continue };

        let mut point = DataPoint::builder("metrics").tag("device_id", device_id.to_string());

        #[cfg(debug_assertions)] {
            log::info!("[DEBUG][FACTS][INFLUX] It contains 'metrics'>'device_id'>{}", device_id);
        }

        let device_requested_metrics = match Cache::instance().get_device_requested_metrics(device_id).await {
            Some(m) => m, None => continue
        };

        for metric in device_requested_metrics {
            let value = facts.metrics
                .get(&metric);

            let value = match value {
                Some(v) => v, None => continue
            };

            #[cfg(debug_assertions)] {
                log::info!("                       {} -> {}", &metric, value);
            }
            point = point.field(metric, value.clone());
        }

        let point = match point.build() { Ok(v) => v, Err(_) => continue };
        points.push(point);
    }

    let result = influx_client.write(&bucket, stream::iter(points)).await;

    if let Err(e) = result {
        log::error!("[ERROR][FACTS][INFLUX] Failed to update database with gathered metrics with InfluxError = '{e}'");
    }
}
