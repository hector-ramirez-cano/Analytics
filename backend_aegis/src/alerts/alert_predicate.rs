use serde::{Deserialize, Deserializer, Serialize, Serializer};

use crate::alerts::{Accessor, AlertPredicate, AlertPredicateOperation};
use crate::types::{MetricSet, MetricValue};

impl AlertPredicate {

    pub fn eval(&self, dataset_left: &MetricSet, dataset_right: &MetricSet) -> bool {
        
        // Resolve sides
        let (left, op, right) = match self {
            AlertPredicate::LeftConst(left, op, accessor) => {
                (Some(left), op, accessor.access(&dataset_right))
            },
            AlertPredicate::RightConst(accessor, op, right) => {
                (accessor.access(&dataset_left), op, Some(right))
            },
            AlertPredicate::Variable(accessor_left, op, accesor_right) => {
                (accessor_left.access(&dataset_left), op, accesor_right.access(&dataset_right))
            },
        };
        #[cfg(debug_assertions)] { log::info!("[DEBUG][ALERTS][EVAL] Evaluating predicate with actual = {:?} {:?} {:?}", left, op, right); }

        // Unwrap if valid
        let (left, right) = if let Some(left) = left && let Some(right) = right {
            (left, right)
        } else {
            return false;
        };
        
        // apply operation
        op.eval(left, right)
    }

    pub fn get_op(&self) -> AlertPredicateOperation {
        match self {
            AlertPredicate::LeftConst (_, op, _) => op.clone(),
            AlertPredicate::RightConst(_, op, _) => op.clone(),
            AlertPredicate::Variable  (_, op, _) => op.clone(),
        }
    }

    pub fn eval_left<'a>(&'a self, dataset_left : &'a MetricSet) -> Option<&'a MetricValue> {
        match self {
            AlertPredicate::LeftConst(metric_value, _, _) => Some(metric_value),
            AlertPredicate::RightConst(accessor, _, _) => accessor.access(&dataset_left),
            AlertPredicate::Variable(accessor, _, _) => accessor.access(&dataset_left),
        }
    }

    pub fn eval_right<'a>(&'a self, dataset_right : &'a MetricSet) -> Option<&'a MetricValue> {
        match self {
            AlertPredicate::LeftConst(_, _, accessor) => accessor.access(&dataset_right),
            AlertPredicate::RightConst(_, _, metric_value) => Some(metric_value),
            AlertPredicate::Variable(_, _, accessor) => accessor.access(&dataset_right),
        }
    }
}

impl ToString for AlertPredicate {
    fn to_string(&self) -> String {
        match self {
            AlertPredicate::LeftConst(metric_value, op, accessor) => format!("{} {} {}", metric_value.to_string(), op.to_string(), accessor.key),
            AlertPredicate::RightConst(accessor, op, metric_value) => format!("{} {} {}", accessor.key, op.to_string(),metric_value.to_string() ),
            AlertPredicate::Variable(accessor, op, accessor1) => format!("{} {} {}", accessor.key, op.to_string(), accessor1.key),
        }
    }
}


// --- Serialize ---
impl Serialize for AlertPredicate {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where S: Serializer {
        use serde::ser::SerializeMap;
        let mut map = serializer.serialize_map(Some(3))?;
        match self {
            AlertPredicate::LeftConst(left_val, op, right_acc) => {
                map.serialize_entry("left", left_val)?;
                map.serialize_entry("op", op)?;
                map.serialize_entry("right", &format!("&{}", right_acc.key))?;
            }
            AlertPredicate::RightConst(left_acc, op, right_val) => {
                map.serialize_entry("left", &format!("&{}", left_acc.key))?;
                map.serialize_entry("op", op)?;
                map.serialize_entry("right", right_val)?;
            }
            AlertPredicate::Variable(left_acc, op, right_acc) => {
                map.serialize_entry("left", &format!("&{}", left_acc.key))?;
                map.serialize_entry("op", op)?;
                map.serialize_entry("right", &format!("&{}", right_acc.key))?;
            }
        }
        map.end()
    }
}

// --- Deserialize ---
impl<'de> Deserialize<'de> for AlertPredicate {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where D: Deserializer<'de> {
        #[derive(Deserialize, Debug)]
        struct Raw {
            left: serde_json::Value,
            op: AlertPredicateOperation,
            right: serde_json::Value,
        }

        let raw = Raw::deserialize(deserializer)?;

        let left_is_accessor = raw.left.is_string() && raw.left.as_str().unwrap().starts_with('&');
        let right_is_accessor = raw.right.is_string() && raw.right.as_str().unwrap().starts_with('&');

        match (left_is_accessor, right_is_accessor) {
            (true, true) => {
                let raw_left = raw.left.as_str().unwrap();
                let raw_right = raw.right.as_str().unwrap();
                let left_acc = Accessor::new(raw_left.trim_start_matches('&'));
                let right_acc = Accessor::new(raw_right.trim_start_matches('&'));
                Ok(AlertPredicate::Variable(left_acc, raw.op, right_acc))
            },
            (true, false) => {
                let raw_left = raw.left.as_str().unwrap();
                let left_acc = Accessor::new(raw_left.trim_start_matches('&'));
                let right_val: MetricValue = raw.right.into();
                Ok(AlertPredicate::RightConst(left_acc, raw.op, right_val))
            },
            (false, true) => {
                let raw_right = raw.right.as_str().unwrap();
                let right_acc = Accessor::new(raw_right.trim_start_matches('&'));
                let left_val: MetricValue = raw.left.into();
                Ok(AlertPredicate::LeftConst(left_val, raw.op, right_acc))
            },
            (false, false) => {
                log::error!("[ERROR][ALERTS] Rule can't have both sides as constants");
                Err(serde::de::Error::custom("[ERROR][ALERTS] Rule can't have both sides as constants"))

            }
        }
    }
}
