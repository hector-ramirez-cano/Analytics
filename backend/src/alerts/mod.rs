use std::collections::HashSet;
use std::fmt;

use sqlx::types::chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, Type};

use crate::alerts::alert_backend::AlertBackend;
use crate::misc::{ts_to_datetime_utc, opt_ts_to_datetime_utc};
use crate::model::facts::{fact_gathering_backend::FactMessage};
use crate::model::data::{device::Device, group::Group};
use crate::model::cache::Cache;
use crate::types::{AlertAckActor, AlertEventId, AlertRuleId, AlertTargetId, EpochSeconds};
use crate::types::MetricValue;

pub mod alert_severity;
pub mod alert_predicate;
pub mod alert_predicate_operation;
pub mod alert_event;
pub mod accessor;
pub mod alert_reduce_logic;
pub mod alert_backend;
pub mod telegram_backend;
pub mod operand_modifier;
pub mod tests;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type, Hash)]
#[sqlx(type_name = "AlertSeverity", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum AlertSeverity {
    Emergency,
    Alert,
    Critical,
    Error,
    Warning,
    Notice,
    Info,
    Debug,

    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type)]
#[serde(rename_all = "snake_case")]
pub enum AlertPredicateOperation {
    MoreThan,
    MoreThanEqual,
    LessThan,
    LessThanEqual,
    Equal,
    NotEqual,
    Contains,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AlertEvent {
    #[serde(rename = "alert-id")]
    pub alert_id: AlertEventId,

    #[serde(rename = "alert-time", with = "chrono::serde::ts_seconds_option")]
    pub alert_time: Option<DateTime<Utc>>,

    #[serde(rename = "ack-time", with = "chrono::serde::ts_seconds_option")]
    pub ack_time: Option<DateTime<Utc>>,

    #[serde(rename = "requires-ack")]
    pub requires_ack: bool,

    pub severity: AlertSeverity,

    pub message: String,

    #[serde(rename = "target-id")]
    pub target_id: AlertTargetId,

    pub ws_notified: bool,
    pub db_notified: bool,
    pub acked: bool,

    #[serde(rename = "rule-id")]
    pub rule_id: Option<AlertRuleId>,

    pub value: String,
}

/// Which side (if any) is constant
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConstSide {
    None,
    Left,
    Right,
}


#[derive(Debug, Clone)]
pub struct Accessor {
    key: String,
}


#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename="lowercase")]
pub enum OperandModifier {
    /// Arithemtic operation `Addition`. Always results in MetricValue::Number
    Add(f64),

    /// Arithemtic operation `Multiplication`. Always results in MetricValue::Number
    Mul(f64),
    
    /// Arithemtic operation `Modulo`. Always results in MetricValue::Integer. Contents are denominator
    Mod(i64),

    /// Arithemtic operation `Remainder`. Always results in MetricValue::Number. Contents are denominator
    Rem(f64),

    /// Arithemtic operation `Power`. Always results in MetricValue::Number. Contents are expontent
    Pow(f64),

    /// String operation `Append`. Always results in MetricValue::String. Contents are suffix
    Append(String),

    /// String operation `Preppend`. Always results in MetricValue::String. Contents are prefix
    Prepend(String),

    /// String operation `Trim`. Always results in MetricValue::String.
    Trim,

    /// String operation `Replace`. Always results in MetricValue::String. Contents are pattern and replacement, respectively
    Replace{pattern: String, with: String},

    /// String operation `ReplaceAll`. Always results in MetricValue::String. Contents are pattern and replacement, respectively
    ReplaceN{pattern: String, with: String, count: usize},

    /// String operation `toLower`. Always results in MetricValue::String. Turns the contents into lowercase
    Lower,

    /// String operation `toUpper`. Always results in MetricValue::String. Turns the contents into uppercase
    Upper,

    /// Multi operation. Applies `first`, and subsequently `then`
    Multi{ first: Box<Self>, then: Box<Self> },

    /// Default operation. Does nothing
    #[serde(other)]
    None
}


#[derive(Debug, Clone)]
pub enum AlertPredicate {
    LeftConst (OperandModifier, MetricValue, AlertPredicateOperation, Accessor   , OperandModifier),
    RightConst(OperandModifier, Accessor   , AlertPredicateOperation, MetricValue, OperandModifier),
    Variable  (OperandModifier, Accessor   , AlertPredicateOperation, Accessor   , OperandModifier),
}


#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AlertReduceLogic {
    All,
    Any,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, Eq, PartialEq)]
#[serde(rename_all="lowercase")]
pub enum AlertRuleKind {
    /// Evaluates using only data in the current dataset.
    /// Useful for predicates that don't require any external data.
    /// Such as any time a given value is spotted, like 'SSH' in syslog
    Simple,

    /// Evaluates using the current data set, and the one previous to it
    /// Useful for spotting changes (hence, delta) in usually static values.
    /// Such as UP status, reachability, etc
    Delta,

    /// Evaluates using only the data in the current dataset,
    /// but keeps track of when the alert first evaluated to true.
    /// Once at least [seconds] have passed since first continuous true evaluations
    /// it'll raise.
    /// Useful for debouncing certain metrics, such as ICMP_RTT.
    /// We don't care that a single packet took longer than it should've,
    /// We only care if that behavior persists AND sustains throughout [seconds].
    /// If at any evaluation point the value is false, the counter will reset
    Sustained { seconds: EpochSeconds }
}

impl Default for AlertRuleKind {
    fn default() -> Self {
        AlertRuleKind::Simple
    }
}

impl fmt::Display for AlertRuleKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AlertRuleKind::Simple => f.write_str("simple"),
            AlertRuleKind::Delta => f.write_str("delta"),
            AlertRuleKind::Sustained{seconds: _} => f.write_str("sustained"),
        }.unwrap();

        fmt::Result::Ok(())
    }
}

pub mod alert_rule;
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AlertRule {
    #[serde(rename = "id", default)] // Might not be present in the JSON definition, but will get overriden by the database actual values
    pub rule_id: AlertRuleId,

    #[serde(rename = "name", default)] // Might not be present in the JSON definition, but will get overriden by the database actual values
    pub name: String,

    #[serde(rename = "requires-ack", default)] // Might not be present in the JSON definition, but will get overriden by the database actual values
    pub requires_ack: bool,

    #[serde(rename= "severity")]
    pub severity: AlertSeverity,

    #[serde(rename = "target")]
    pub target_item: AlertTargetId,

    #[serde(rename = "reduce-logic")]
    pub reduce_logic: AlertReduceLogic,

    #[serde(rename = "predicates")]
    pub predicates: Vec<AlertPredicate>,

    #[serde(rename="data-source")]
    pub data_source: AlertDataSource,

    #[serde(rename="rule-type")]
    pub rule_kind: AlertRuleKind
}

pub mod alert_filters;
#[derive(Debug, Deserialize)]
pub struct AlertFilters {
    #[serde(deserialize_with = "ts_to_datetime_utc", rename = "start")]
    pub start_time: DateTime<Utc>,

    #[serde(deserialize_with = "ts_to_datetime_utc", rename = "end")]
    pub end_time: DateTime<Utc>,

    #[serde(skip_serializing_if = "Option::is_none", rename = "alert-id")]
    pub alert_id: Option<AlertEventId>,

    #[serde(default, deserialize_with = "opt_ts_to_datetime_utc", skip_serializing_if = "Option::is_none", rename = "ack-start")]
    pub ack_start_time: Option<DateTime<Utc>>,

    #[serde(default, deserialize_with = "opt_ts_to_datetime_utc", skip_serializing_if = "Option::is_none", rename = "ack-end")]
    pub ack_end_time: Option<DateTime<Utc>>,

    #[serde(rename = "severity")]
    pub severities: HashSet<AlertSeverity>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none", rename = "ack-actor")]
    pub ack_actor: Option<AlertAckActor>,

    #[serde(skip_serializing_if = "Option::is_none", rename = "target-id")]
    pub target_id: Option<AlertTargetId>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub offset: Option<i64>,

    #[serde(skip_serializing_if = "Option::is_none", rename = "requires-ack")]
    pub requires_ack: Option<bool>,

    #[serde(rename = "page-size", skip_serializing_if = "Option::is_none")]
    pub page_size: Option<i64>,
}



#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all="lowercase")]
pub enum AlertDataSource {
    Facts,
    Syslog
}

/// Defines the items that can be evaluated against a rule.
#[derive(Debug, Clone)]
pub enum EvaluableItem {
    Device (Device),
    Group (Group)
}

type EvalResult= (OperandModifier, MetricValue, AlertPredicateOperation,MetricValue, OperandModifier);

impl EvaluableItem {

    async fn eval_device<'a>(device: Device, rule: &'a AlertRule, dataset_left: &'a FactMessage, dataset_right: &'a FactMessage) 
        -> Option<(EvaluableItem, Vec<EvalResult>)> {
        let dataset_right = &dataset_right.get(&device.management_hostname)?.metrics;

        #[cfg(debug_assertions)] { log::info!("[DEBUG][ALERTS][EVAL] Evaluating rule for device={} kind is {}", device.management_hostname, rule.rule_kind); }
        match rule.rule_kind {
            AlertRuleKind::Simple => {
                if rule.eval_single(&dataset_right) {
                    let which = rule.raising_values(&dataset_right, &dataset_right);
                    Some((EvaluableItem::Device(device), which))
                } else { None }
            },

            AlertRuleKind::Delta => {
                let dataset_left = &dataset_left.get(&device.management_hostname)?.metrics;
                if rule.eval_delta(dataset_left, dataset_right) {
                    let which = rule.raising_values(dataset_left, dataset_right);
                    Some((EvaluableItem::Device(device), which))
                } else { None }
            },
            
            AlertRuleKind::Sustained { seconds } => {
                if !rule.eval_single(&dataset_right) {
                    // returned false, we let the backend know that it should reset the counter (if any)
                    AlertBackend::sustained_reset(rule.rule_id, device.device_id).await;
                    return None
                } 
                
                // Rule returned true
                // has it returned true before?
                let t = match AlertBackend::sustained_check_first_raised(rule.rule_id, device.device_id).await {
                    Some(t) => t ,
                    None => {
                        // Hasn't raised before, we insert it
                        AlertBackend::sustained_set_first_raised(rule.rule_id, device.device_id).await;
                        return None // return None, we can't raise the alert yet
                    },
                };
                // It has, we check if it's time to raise
                if AlertBackend::sustained_should_raise(t, seconds).await {
                    // Dayum, we need to raise. Also reset the alert so it doesn't trigger immediately again
                    let which = rule.raising_values(dataset_right, dataset_right);
                    AlertBackend::sustained_reset(rule.rule_id, device.device_id).await;
                    
                    Some((EvaluableItem::Device(device), which))
                } else {
                    // Not yet, Ferb
                    None
                }
                
            },
        }
    }

    /// Evaluates the rule with the given datasets. Returns the items for which the rule is raised
    pub async fn eval<'a>(self, rule: &'a AlertRule, dataset_left: &'a FactMessage, dataset_right: &'a FactMessage) 
        -> Option<Vec<(EvaluableItem, Vec<EvalResult>)>> {
        let cache = Cache::instance();
        match self {
            EvaluableItem::Group(group) => {
                let members = cache.get_group_device_ids(group.group_id).await?;
                let mut triggered = Vec::new();
                for member in members {
                    let device = match cache.get_evaluable_item(member).await { Some(d) => d, None => continue };

                    match device {
                        EvaluableItem::Group(_) => {
                            log::error!("[ERROR][ALERTS][EVAL] Rule called for group item. Skipping evaluation");
                            continue
                        },
                        EvaluableItem::Device(device) => {
                            let rule_result = EvaluableItem::eval_device(device, rule, dataset_left, dataset_right).await;

                            if let Some(item) = rule_result {
                                triggered.push(item);
                            }
                        },
                    }
                }
                if triggered.is_empty() {
                    return None;
                }
                return Some(triggered)
            },
            EvaluableItem::Device(device) => {
                Some(vec![EvaluableItem::eval_device(device, rule, dataset_left, dataset_right).await?])
            },
        }
    }
}