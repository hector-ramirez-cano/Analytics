use serde::{Deserialize, Deserializer, Serialize, Serializer, de};

use crate::alerts::{Accessor, AlertPredicate, AlertPredicateOperation};
use crate::model::{facts::generics::{MetricSet, MetricValue}};

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
        #[derive(Deserialize)]
        struct Raw {
            left: String,
            op: AlertPredicateOperation,
            right: String,
        }

        let raw = Raw::deserialize(deserializer)?;

        let left_is_accessor = raw.left.starts_with('&');
        let right_is_accessor = raw.right.starts_with('&');

        if left_is_accessor && right_is_accessor {
            log::warn!("Invalid AlertPredicate: both sides marked accessor (left={}, right={})", raw.left, raw.right);
            return Err(de::Error::custom("Both sides cannot be accessors"));
        }

        if left_is_accessor {
            let left_acc = Accessor::new(raw.left.trim_start_matches('&'));
            let right_val: MetricValue = serde_json::from_str(&raw.right)
                .unwrap_or(MetricValue::String(raw.right.clone()));
            Ok(AlertPredicate::RightConst(left_acc, raw.op, right_val))
        } else if right_is_accessor {
            let left_val: MetricValue = serde_json::from_str(&raw.left)
                .unwrap_or(MetricValue::String(raw.left.clone()));
            let right_acc = Accessor::new(raw.right.trim_start_matches('&'));
            Ok(AlertPredicate::LeftConst(left_val, raw.op, right_acc))
        } else {
            let left_acc = Accessor::new(raw.left.trim_start_matches('&'));
            let right_acc = Accessor::new(raw.right.trim_start_matches('&'));
            Ok(AlertPredicate::Variable(left_acc, raw.op, right_acc))
        }
    }
}
