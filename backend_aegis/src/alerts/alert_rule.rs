
use crate::types::{MetricSet, MetricValue};
use crate::alerts::{AlertPredicateOperation, AlertReduceLogic, AlertRule, AlertRuleKind};

impl AlertRule {
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
        match self.rule_kind {
            AlertRuleKind::Simple => {
                for predicate in &self.predicates {
                    if predicate.eval(dataset_right, dataset_right) {
                        let left_value = match predicate.eval_left(dataset_right) { Some(v) => v, None=> continue };
                        let right_value = match predicate.eval_right(dataset_right) { Some(v) => v, None=> continue };
                        let op =  predicate.get_op();
                        result.push((left_value, op, right_value));
                    }
                }
            },
            AlertRuleKind::Delta => {
                for predicate in &self.predicates {
                    if predicate.eval(dataset_left, dataset_right) {
                        let left_value = match predicate.eval_left(dataset_left) { Some(v) => v, None=> continue };
                        let right_value = match predicate.eval_right(dataset_right) { Some(v) => v, None=> continue };
                        let op =  predicate.get_op();
                        result.push((left_value, op, right_value));
                    }
                }
            },
            AlertRuleKind::Sustained { seconds: _} => {
                for predicate in &self.predicates {
                    if predicate.eval(dataset_right, dataset_right) {
                        let left_value = match predicate.eval_left(dataset_right) { Some(v) => v, None=> continue };
                        let right_value = match predicate.eval_right(dataset_right) { Some(v) => v, None=> continue };
                        let op =  predicate.get_op();
                        result.push((left_value, op, right_value));
                    }
                }
            },
        }
        result
    }
}