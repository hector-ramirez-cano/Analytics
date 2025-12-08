use serde::{Deserialize, Deserializer, Serialize, Serializer};

use crate::alerts::{Accessor, AlertPredicate, AlertPredicateOperation, OperandModifier};
use crate::types::{MetricSet, MetricValue};

impl AlertPredicate {

    pub fn eval(&self, dataset_left: &MetricSet, dataset_right: &MetricSet) -> bool {

        // Resolve sides
        let (lmod, left, op, right, rmod) = match self {
            AlertPredicate::LeftConst(lmod, left, op, accessor, rmod) => {
                (lmod, Some(left), op, accessor.access(&dataset_right), rmod)
            },
            AlertPredicate::RightConst(lmod, accessor, op, right, rmod) => {
                (lmod, accessor.access(&dataset_left), op, Some(right), rmod)
            },
            AlertPredicate::Variable(lmod, accessor_left, op, accesor_right, rmod) => {
                (lmod, accessor_left.access(&dataset_left), op, accesor_right.access(&dataset_right), rmod)
            },
        };
        #[cfg(debug_assertions)] { log::info!("[DEBUG][ALERTS][EVAL] Evaluating predicate with actual = {:?}{} {:?} {:?}{}", left, lmod.to_string(), op, right, rmod.to_string()); }

        let (left, right) = if let Some(left) = lmod.eval(left) && let Some(right) = rmod.eval(right) {
            (left, right)
        } else {
            return false;
        };

        // apply operation
        op.eval(&left, &right)
    }

    pub fn get_op(&self) -> AlertPredicateOperation {
        match self {
            AlertPredicate::LeftConst (_, _, op, _, _) => op.clone(),
            AlertPredicate::RightConst(_, _, op, _, _) => op.clone(),
            AlertPredicate::Variable  (_, _, op, _, _) => op.clone(),
        }
    }

    pub fn eval_left<'a>(&'a self, dataset_left : &'a MetricSet) -> Option<MetricValue> {
        match self {
            AlertPredicate::LeftConst (lmod, metric_value, _, _, _) => lmod.eval(Some(metric_value)),
            AlertPredicate::RightConst(lmod, accessor, _, _, _) => lmod.eval(accessor.access(&dataset_left)),
            AlertPredicate::Variable  (lmod, accessor, _, _, _) => lmod.eval(accessor.access(&dataset_left)),
        }
    }

    pub fn get_lmod (&self) -> OperandModifier {
        match self {
            AlertPredicate::LeftConst (op_mod, _, _, _, _) => op_mod.clone(),
            AlertPredicate::RightConst(op_mod, _, _, _, _) => op_mod.clone(),
            AlertPredicate::Variable  (op_mod, _, _, _, _) => op_mod.clone(),
        }
    }

    pub fn get_rmod (&self) -> OperandModifier {
        match self {
            AlertPredicate::LeftConst (_, _, _, _, op_mod) => op_mod.clone(),
            AlertPredicate::RightConst(_, _, _, _, op_mod) => op_mod.clone(),
            AlertPredicate::Variable  (_, _, _, _, op_mod) => op_mod.clone(),
        }
    }

    pub fn eval_right<'a>(&'a self, dataset_right : &'a MetricSet) -> Option<MetricValue> {
        match self {
            AlertPredicate::LeftConst (_, _, _, accessor, rmod) => rmod.eval(accessor.access(&dataset_right)),
            AlertPredicate::RightConst(_, _, _, metric_value, rmod) => rmod.eval(Some(metric_value)),
            AlertPredicate::Variable  (_, _, _, accessor, rmod) => rmod.eval(accessor.access(&dataset_right)),
        }
    }
}

impl ToString for AlertPredicate {
    fn to_string(&self) -> String {
        match self {
            AlertPredicate::LeftConst (lmod, metric_value, op, accessor, rmod) => format!("{}{} {} {}{}", metric_value.to_string    (), lmod.to_string() , op.to_string(), accessor.key, rmod.to_string()),
            AlertPredicate::RightConst(lmod, accessor, op, metric_value, rmod) => format!("{}{} {} {}{}", accessor.key, op.to_string(), lmod.to_string() , metric_value.to_string() , rmod.to_string()),
            AlertPredicate::Variable  (lmod, accessor, op, accessor1, rmod) => format!("{}{} {} {}{}"   , accessor.key, op.to_string(), lmod.to_string() , accessor1.key, rmod.to_string()),
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
            AlertPredicate::LeftConst(lmod, left_val, op, right_acc, rmod) => {
                map.serialize_entry("left-modifier", lmod)?;
                map.serialize_entry("right-modifier", rmod)?;
                map.serialize_entry("left", left_val)?;
                map.serialize_entry("op", op)?;
                map.serialize_entry("right", &format!("&{}", right_acc.key))?;
            }
            AlertPredicate::RightConst(lmod, left_acc, op, right_val, rmod) => {
                map.serialize_entry("left-modifier", lmod)?;
                map.serialize_entry("right-modifier", rmod)?;
                map.serialize_entry("left", &format!("&{}", left_acc.key))?;
                map.serialize_entry("op", op)?;
                map.serialize_entry("right", right_val)?;
            }
            AlertPredicate::Variable(lmod, left_acc, op, right_acc, rmod) => {
                map.serialize_entry("left-modifier", lmod)?;
                map.serialize_entry("right-modifier", rmod)?;
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
            #[serde(rename="left-modifier")]
            left_modifier: Option<OperandModifier>,

            #[serde(rename="right-modifier")]
            right_modifier: Option<OperandModifier>,

            left: serde_json::Value,
            op: AlertPredicateOperation,
            right: serde_json::Value,
        }

        let raw = Raw::deserialize(deserializer)?;

        let left_is_accessor = raw.left.is_string() && raw.left.as_str().unwrap_or_default().starts_with('&');
        let right_is_accessor = raw.right.is_string() && raw.right.as_str().unwrap_or_default().starts_with('&');

        match (left_is_accessor, right_is_accessor) {
            (true, true) => {
                let raw_left = raw.left.as_str().unwrap_or_default();
                let raw_right = raw.right.as_str().unwrap_or_default();
                let left_acc = Accessor::new(raw_left.trim_start_matches('&'));
                let right_acc = Accessor::new(raw_right.trim_start_matches('&'));
                Ok(AlertPredicate::Variable(
                    raw.left_modifier.unwrap_or(OperandModifier::None),
                    left_acc,
                    raw.op,
                    right_acc,
                    raw.right_modifier.unwrap_or(OperandModifier::None)
                ))
            },
            (true, false) => {
                let raw_left = raw.left.as_str().unwrap_or_default();
                let left_acc = Accessor::new(raw_left.trim_start_matches('&'));
                let right_val: MetricValue = raw.right.into();

                Ok(AlertPredicate::RightConst(
                    raw.left_modifier.unwrap_or(OperandModifier::None),
                    left_acc,
                    raw.op,
                    right_val,
                    raw.right_modifier.unwrap_or(OperandModifier::None)
                ))
            },
            (false, true) => {
                let raw_right = raw.right.as_str().unwrap_or_default();
                let right_acc = Accessor::new(raw_right.trim_start_matches('&'));
                let left_val: MetricValue = raw.left.into();
                Ok(AlertPredicate::LeftConst(
                    raw.left_modifier.unwrap_or(OperandModifier::None),
                    left_val,
                    raw.op,
                    right_acc,
                    raw.right_modifier.unwrap_or(OperandModifier::None)
                ))
            },
            (false, false) => {
                log::error!("[ERROR][ALERTS] Rule can't have both sides as constants");
                Err(serde::de::Error::custom("[ERROR][ALERTS] Rule can't have both sides as constants"))

            }
        }
    }
}
