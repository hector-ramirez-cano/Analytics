use std::collections::HashMap;

use crate::types::MetricValue;

pub trait ToMetrics {
    /// Convert `self` into MetricValue entries, using `prefix` as the current metric name.
    /// Pass `None` for top-level to avoid a leading separator.
    fn to_metrics(&self, prefix: Option<&str>) -> HashMap<String, MetricValue>;
}

impl ToMetrics for serde_json::Value {
    fn to_metrics(&self, prefix: Option<&str>) -> HashMap<String, MetricValue> {
        fn join(prefix: Option<&str>, key: &str) -> String {
            match prefix {
                Some(p) if !p.is_empty() => format!("{}_{}", p, key),
                _ => key.to_string(),
            }
        }

        let mut out: HashMap<String, MetricValue> = HashMap::new();

        match self {
            serde_json::Value::Object(map) => {
                for (k, v) in map {
                    let name = join(prefix, k);
                    out.extend( v.to_metrics(Some(&name)));
                }
            }

            serde_json::Value::Array(arr) => {
                let name = prefix.unwrap_or_default().to_string();
                let mut children = Vec::with_capacity(arr.len());
                for (idx, item) in arr.iter().enumerate() {
                    // Use index to keep element names unique; change if you prefer another scheme
                    let item_name = if name.is_empty() {
                        idx.to_string()
                    } else {
                        format!("{}_{}", name, idx)
                    };
                    children.extend(item.to_metrics(Some(&item_name)).into_values());
                }
                out.insert(name, MetricValue::Array(children));
            }

            serde_json::Value::String(s) => {
                let name = prefix.unwrap_or_default().to_string();
                out.insert(name, MetricValue::String(s.clone()));
            }

            serde_json::Value::Number(n) => {
                let f = n.as_f64()
                    .or_else(|| n.as_i64().map(|i| i as f64))
                    .or_else(|| n.as_u64().map(|u| u as f64))
                    .unwrap_or(0.0);
                let name = prefix.unwrap_or_default().to_string();
                out.insert(name, MetricValue::Number(f.into()));
            }

            serde_json::Value::Bool(b) => {
                let name = prefix.unwrap_or_default().to_string();
                out.insert(name, MetricValue::Boolean(*b));
            }

            serde_json::Value::Null => {
                let name = prefix.unwrap_or_default().to_string();
                out.insert(name, MetricValue::Null());
            }
        }

        out
    }
}

/// Recursively merges `src` into `dst`.
/// - If both values are arrays, merges them element-wise.
/// - Otherwise, `src` overwrites `dst`.
pub fn recursive_merge(
    dst: &mut HashMap<String, MetricValue>,
    src: &HashMap<String, MetricValue>,
) {
    for (key, src_val) in src {
        match (dst.get_mut(key), src_val) {
            // Merge arrays element-wise (optional: customize strategy)
            (Some(MetricValue::Array(dst_arr)), MetricValue::Array(src_arr)) => {
                dst_arr.extend(src_arr.clone()); // or use a smarter merge strategy
            }

            // Overwrite or insert
            _ => {
                dst.insert(key.clone(), src_val.clone());
            }
        }
    }
}
