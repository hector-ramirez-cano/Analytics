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

/// Pretty self explanatory. Severity of the alert rule
/// In case a value given is not valid, will default to Unknown
/// Equivalent to `alertseverity` enum in PostgreSQL
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

/// Alert Operation as a boolean operation to be applied between operands
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type)]
#[serde(rename_all = "snake_case")]
pub enum AlertPredicateOperation {
    /// Resolves to `>`. Arithmetic operation. Can only be applied to numbers
    MoreThan,

    /// Resolves to `>=`. Arithmetic operation. Can only be applied to numbers
    MoreThanEqual,

    /// Resolves to `<`. Arithmetic operation. Can only be applied to numbers
    LessThan,

    /// Resolves to `<=`. Arithmetic operation. Can only be applied to numbers
    LessThanEqual,

    /// Resolves to `==`. Can be applied to any items
    Equal,

    /// Resolves to `!=`. Can be applied to any items
    NotEqual,

    /// Resolves to a `contains` call. Can be applied to strings and arrays, where the left side is string and array, and right can be anything
    /// Such that, for instance:
    /// &syslog_message `Contains` "ssh"
    Contains,

    /// Default value. If encountered, will always resolve to false
    #[serde(other)]
    Unknown,
}

/// Event raised by an alert rule, indicating an instance at which the alert rule evaluated to true
/// Will be broadcast to all listeners; local, database, websocket and Telegram
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AlertEvent {
    /// Unique database ID for this alert event
    #[serde(rename = "alert-id")]
    pub alert_id: AlertEventId,

    /// Time at which the alert happened
    #[serde(rename = "alert-time", with = "chrono::serde::ts_seconds_option")]
    pub alert_time: Option<DateTime<Utc>>,

    /// Time at which the alert was acked
    #[serde(rename = "ack-time", with = "chrono::serde::ts_seconds_option")]
    pub ack_time: Option<DateTime<Utc>>,

    /// Whether the alert requires an ack by an authorized user
    #[serde(rename = "requires-ack")]
    pub requires_ack: bool,

    /// Severity of the alert event
    pub severity: AlertSeverity,

    /// Generated message indicating extra details
    pub message: String,

    /// Target id of a device that triggered the alert
    #[serde(rename = "target-id")]
    pub target_id: AlertTargetId,

    /// Whether the websocket listeners have been notified. If it fails, the event will be silently discarded
    pub ws_notified: bool,

    /// Whether the database listeners have been notified. If it fails, the event will be requeued until they can be notified
    pub db_notified: bool,

    /// Whether the message has been acked. Dynamically generated from database
    pub acked: bool,

    /// AlertRule that triggered the alert. Optional, as a rule that raised it could've been deleted from the database
    /// At creation, this is guaranteed to not be None
    #[serde(rename = "rule-id")]
    pub rule_id: Option<AlertRuleId>,
    
    /// String representation of the value that raised.
    pub value: String,
}

/// Which side (if any) is constant
/// Note: only one side can be constant, as both sides being constant would result in always true, or always false; useless.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConstSide {
    None,
    Left,
    Right,
}

/// Defines a string to be used to access into a dictionary during rule evaluation
#[derive(Debug, Clone)]
pub struct Accessor {
    /// String key that will be used to access into the dictionary.
    /// It's always prepended with `&`, and it's used to discriminate
    /// Accessors from constant strings.
    key: String,
}

/// Defines which optional operation to apply to an operand.
/// If the types are not valid, the operation will be ignored
/// 
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

/// Defines an Alert predicate for which either one side is constant, or both are variable.
/// To be used for AlertRules to evaluate multiple conditions as `predicates`
/// Operand modifiers can be used to alter the evaluated value dynamically.
/// The order is: LeftModifier, LeftOperand, Operation, RightOperand, RightModifier
/// Like the following: (Add(0.5), "&icmp_rtt", MoreThan, 70, Mul(1.5))
#[derive(Debug, Clone)]
pub enum AlertPredicate {
    LeftConst (OperandModifier, MetricValue, AlertPredicateOperation, Accessor   , OperandModifier),
    RightConst(OperandModifier, Accessor   , AlertPredicateOperation, MetricValue, OperandModifier),
    Variable  (OperandModifier, Accessor   , AlertPredicateOperation, Accessor   , OperandModifier),
}

/// Logic to be used to reduce more than one predicate, in order to consider this rule to be raised.
/// Either all raise, or any raise.
/// Equivalent to boolean operations for `*` and `+`, respectively
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AlertReduceLogic {
    All,
    Any,
    #[serde(other)]
    Unknown,
}

/// Kind of rule to be evaluated. Changes which data will be used, and the behavior to raise the alert.
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
        }.unwrap_or(());

        fmt::Result::Ok(())
    }
}

pub mod alert_rule;
/// Defines a single AlertRule, which will be evaluated once new data arrives.
/// In the case of raising the alert, listeners will be notified that this instance was raised
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AlertRule {
    /// Unique Database id, numeric
    #[serde(rename = "id", default)] // Might not be present in the JSON definition, but will get overriden by the database actual values
    pub rule_id: AlertRuleId,

    /// Display name, to be used when notifying listeners which rule raised.
    /// Uniqueness is not enforced
    #[serde(rename = "name", default)] // Might not be present in the JSON definition, but will get overriden by the database actual values
    pub name: String,

    /// Whether the alert rule requires an authenticated user to ack the alert once it arrives
    #[serde(rename = "requires-ack", default)] // Might not be present in the JSON definition, but will get overriden by the database actual values
    pub requires_ack: bool,

    /// Severity of the alert event raised if this alert rule evaluates to true
    #[serde(rename= "severity")]
    pub severity: AlertSeverity,

    /// Target device or devices for which the rule will be evaluated.
    /// Note: if the target or a member of target does not contain a variable accessed through an accessor, the rule will silently skip that device
    #[serde(rename = "target")]
    pub target_item: AlertTargetId,

    /// Predicate reduce logic to be used for evaluating the rule
    /// Equivalent to boolean algebra operations `*` and `+`
    #[serde(rename = "reduce-logic")]
    pub reduce_logic: AlertReduceLogic,

    /// List of predicates to be evaluated against the dataset. AlertReduceLogic will be applied to it
    #[serde(rename = "predicates")]
    pub predicates: Vec<AlertPredicate>,

    /// Data source from which the dataset will be constructed. Rules can only be applied to one datasource at a time
    #[serde(rename="data-source")]
    pub data_source: AlertDataSource,

    /// Kind of rule to be evaluated. Changes which data will be used, and the behavior to raise the alert.
    #[serde(rename="rule-type")]
    pub rule_kind: AlertRuleKind
}

pub mod alert_filters;
/// Filters for AlertEvents being recalled from the database
#[derive(Debug, Deserialize)]
pub struct AlertFilters {
    /// Range start from which to start the search. Mandatory.
    #[serde(deserialize_with = "ts_to_datetime_utc", rename = "start")]
    pub start_time: DateTime<Utc>,

    /// Range start at which to end the search. Mandatory.
    #[serde(deserialize_with = "ts_to_datetime_utc", rename = "end")]
    pub end_time: DateTime<Utc>,

    /// AlertEvent id to be search
    #[serde(skip_serializing_if = "Option::is_none", rename = "alert-id")]
    pub alert_id: Option<AlertEventId>,

    /// Range start from which to start the ack search. Optional
    #[serde(default, deserialize_with = "opt_ts_to_datetime_utc", skip_serializing_if = "Option::is_none", rename = "ack-start")]
    pub ack_start_time: Option<DateTime<Utc>>,

    /// Range end at which to end the ack search. Optional
    #[serde(default, deserialize_with = "opt_ts_to_datetime_utc", skip_serializing_if = "Option::is_none", rename = "ack-end")]
    pub ack_end_time: Option<DateTime<Utc>>,

    /// Severity of the event. Works as a bitmask. If it's present in the hashset, it will be retrieved from the database
    #[serde(rename = "severity")]
    pub severities: HashSet<AlertSeverity>,

    /// Contents of the message to be fuzzy searched
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,

    /// Ack actor that ack'd the message
    #[serde(skip_serializing_if = "Option::is_none", rename = "ack-actor")]
    pub ack_actor: Option<AlertAckActor>,

    /// Device or group target ID to which the rule applies to
    #[serde(skip_serializing_if = "Option::is_none", rename = "target-id")]
    pub target_id: Option<AlertTargetId>,

    /// Offset of rows. Not directly accessible by the user, but used internally for pagination
    #[serde(skip_serializing_if = "Option::is_none")]
    pub offset: Option<i64>,

    /// Whether the alert event has the `requires_ack` flag set
    #[serde(skip_serializing_if = "Option::is_none", rename = "requires-ack")]
    pub requires_ack: Option<bool>,

    /// Page Size to be retrieved per message
    #[serde(rename = "page-size", skip_serializing_if = "Option::is_none")]
    pub page_size: Option<i64>,
}

/// Where the data comes from for an AlertRule. Only one source can be used for rule
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

type EvalResult= (OperandModifier, MetricValue, AlertPredicateOperation, MetricValue, OperandModifier);

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