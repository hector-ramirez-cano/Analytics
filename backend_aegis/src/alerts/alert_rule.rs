use std::str::FromStr;

use crate::model::facts::generics::{MetricSet, MetricValue};
use crate::{alerts::{AlertPredicate, AlertPredicateOperation, AlertReduceLogic, AlertRule, AlertSeverity}};

impl AlertRule {
    pub fn from_json(rule_id: i64, name: String, requires_ack: bool, definition: serde_json::Value) -> Option<Self> {
        let definition = if let serde_json::Value::Object(d) = definition { d } else { return None; };

        let severity = AlertSeverity::from_str(definition.get("severity")?.as_str()?).ok()?;
        let target_item = definition.get("target")?.as_i64()?;
        let reduce_logic = AlertReduceLogic::from_str_fallback(definition.get("reduce-logic")?.as_str()?)?;
        let predicates : Vec<AlertPredicate> = serde_json::from_value(definition.get("predicates")?.clone()).ok()?;
        let data_source = serde_json::from_value(definition.get("source")?.clone()).ok()?;
        let is_delta_rule = definition.get("is-delta-rule")?.as_bool()?;

        // TODO: Validate only predicate operation can be equal or not equal if is_delta_rule is true

        Some(AlertRule {
            rule_id,
            name,
            requires_ack,
            severity,
            target_item,
            reduce_logic,
            predicates,
            data_source,
            is_delta_rule,
        })
    }

    /// Evaluates an alert rule that compares the most recent, with the previous metric set, to trigger on value changes
    /// Typically left is previous, right is current
    pub fn eval_delta(&self, dataset_left: &MetricSet, dataset_right: &MetricSet) -> bool {
        match self.reduce_logic {
            AlertReduceLogic::All => self.predicates.iter().all(|p| p.eval(dataset_left, dataset_right)),
            AlertReduceLogic::Any => self.predicates.iter().any(|p| p.eval(dataset_left, dataset_right)),
            AlertReduceLogic::Unknown => {
                log::warn!("[WARN ][ALERTS] Trying to eval rule with Unknown reduce logic. Skipping...");
                false
            },
        }
    }

    /// Evaluates an alert rule that triggers only on the most recent MetricSet
    pub fn eval_single(&self, dataset: &MetricSet) -> bool {
        match self.reduce_logic {
            AlertReduceLogic::All => self.predicates.iter().all(|p| p.eval(dataset, dataset)),
            AlertReduceLogic::Any => self.predicates.iter().any(|p| p.eval(dataset, dataset)),
            AlertReduceLogic::Unknown => {
                log::warn!("[WARN ][ALERTS] Trying to eval rule with Unknown reduce logic. Skipping...");
                false
            },
        }
    }

    pub fn raising_values<'a >(&'a self, dataset_left: &'a MetricSet, dataset_right: &'a MetricSet) -> Vec<(&'a MetricValue, AlertPredicateOperation, &'a MetricValue)> {
        // we know a predicate has raised. We need to know which one(s), and with which values

        let mut result = Vec::new();
        if self.is_delta_rule {
            for predicate in &self.predicates {
                if predicate.eval(dataset_left, dataset_right) {
                    let left_value = match predicate.eval_left(dataset_left) { Some(v) => v, None=> continue };
                    let right_value = match predicate.eval_right(dataset_right) { Some(v) => v, None=> continue };
                    let op =  predicate.get_op();
                    result.push((left_value, op, right_value));
                }
            }
        } else {
            for predicate in &self.predicates {
                if predicate.eval(dataset_right, dataset_right) {
                    let left_value = match predicate.eval_left(dataset_right) { Some(v) => v, None=> continue };
                    let right_value = match predicate.eval_right(dataset_right) { Some(v) => v, None=> continue };
                    let op =  predicate.get_op();
                    result.push((left_value, op, right_value));
                }
            }
        }

        result
    }
}