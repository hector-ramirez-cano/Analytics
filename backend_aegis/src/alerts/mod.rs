use std::collections::HashSet;

use sqlx::types::chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, Type};

use crate::misc::{ts_to_datetime_utc, opt_ts_to_datetime_utc};
use crate::model::facts::{fact_gathering_backend::FactMessage, generics::MetricValue};
use crate::model::data::{device::Device, group::Group};
use crate::model::cache::Cache;

pub mod alert_severity;
pub mod alert_predicate;
pub mod alert_predicate_operation;
pub mod alert_event;
pub mod accessor;
pub mod alert_reduce_logic;
pub mod alert_backend;
pub mod telegram_backend;

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
    // Not in DB enum, but useful for fallbacks
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
    pub alert_id: i64,

    #[serde(rename = "alert-time", with = "chrono::serde::ts_seconds_option")]
    pub alert_time: Option<DateTime<Utc>>,

    #[serde(rename = "ack-time", with = "chrono::serde::ts_seconds_option")]
    pub ack_time: Option<DateTime<Utc>>,

    #[serde(rename = "requires-ack")]
    pub requires_ack: bool,

    pub severity: AlertSeverity,

    pub message: String,

    #[serde(rename = "target-id")]
    pub target_id: i64,

    pub ws_notified: bool,
    pub db_notified: bool,
    pub acked: bool,

    #[serde(rename = "rule-id")]
    pub rule_id: Option<i64>,

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


#[derive(Debug, Clone)]
pub enum AlertPredicate {
    LeftConst (MetricValue, AlertPredicateOperation, Accessor   ),
    RightConst(Accessor   , AlertPredicateOperation, MetricValue),
    Variable  (Accessor   , AlertPredicateOperation, Accessor   ),
}


#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AlertReduceLogic {
    All,
    Any,
    #[serde(other)]
    Unknown,
}

pub mod alert_rule;
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AlertRule {
    #[serde(rename = "id")]
    pub rule_id: i64,

    #[serde(rename = "name")]
    pub name: String,

    #[serde(rename = "requires-ack")]
    pub requires_ack: bool,

    #[serde(rename= "severity")]
    pub severity: AlertSeverity,

    #[serde(rename = "target")]
    pub target_item: i64,

    #[serde(rename = "reduce-logic")]
    pub reduce_logic: AlertReduceLogic,

    #[serde(rename = "predicates")]
    pub predicates: Vec<AlertPredicate>,

    #[serde(rename="data-source")]
    pub data_source: AlertDataSource,

    #[serde(rename="is-delta-rule")]
    pub is_delta_rule: bool
}

pub mod alert_filters;
#[derive(Debug, Deserialize)]
pub struct AlertFilters {
    #[serde(deserialize_with = "ts_to_datetime_utc")]
    pub start_time: DateTime<Utc>,

    #[serde(deserialize_with = "ts_to_datetime_utc")]
    pub end_time: DateTime<Utc>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub alert_id: Option<i64>,

    #[serde(default, deserialize_with = "opt_ts_to_datetime_utc", skip_serializing_if = "Option::is_none")]
    pub ack_start_time: Option<DateTime<Utc>>,

    #[serde(default, deserialize_with = "opt_ts_to_datetime_utc", skip_serializing_if = "Option::is_none")]
    pub ack_end_time: Option<DateTime<Utc>>,

    pub severities: HashSet<AlertSeverity>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub ack_actor: Option<i64>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_id: Option<i64>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub offset: Option<i64>,

    #[serde(skip_serializing_if = "Option::is_none")]
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
pub enum EvaluableItem {
    Device (Device),
    Group (Group)
}

type EvalResult<'a> = (&'a MetricValue, AlertPredicateOperation, &'a MetricValue);

impl EvaluableItem {

    async fn eval_device<'a>(device: Device,  rule: &'a AlertRule, dataset_left: &'a FactMessage, dataset_right: &'a FactMessage) -> Option<(EvaluableItem, Vec<EvalResult<'a>>)> {
        #[cfg(debug_assertions)] { log::info!("[DEBUG][ALERTS][EVAL] Evaluating rule for device={}", device.management_hostname); }
        let dataset_right = dataset_right.0.get(&device.management_hostname)?;

        if rule.is_delta_rule {
            #[cfg(debug_assertions)] { log::info!("[DEBUG][ALERTS][EVAL] Evaluating rule for device={} is delta", device.management_hostname); }
            let dataset_left = &dataset_left.0;
            let dataset_left = dataset_left.get(&device.management_hostname)?;
            if rule.eval_delta(dataset_left, dataset_right) {
                let which = rule.raising_values(dataset_left, dataset_right);
                Some((EvaluableItem::Device(device), which))
            } else { None }
        } else {
            #[cfg(debug_assertions)] { log::info!("[DEBUG][ALERTS][EVAL] Evaluating rule for device={} is not delta", device.management_hostname); }
            if rule.eval_single(dataset_right) {
                let which = rule.raising_values(dataset_right, dataset_right);
                Some((EvaluableItem::Device(device), which))
            } else { None }
        }
    }

    /// Evaluates the rule with the given datasets. Returns the items for which the rule is raised
    pub async fn eval<'a>(self, rule: &'a AlertRule, dataset_left: &'a FactMessage, dataset_right: &'a FactMessage) -> Option<Vec<(EvaluableItem, Vec<EvalResult<'a>>)>> {
        let cache = Cache::instance();
        match self {
            EvaluableItem::Group(group) => {
                let members = cache.get_group_device_ids(group.group_id)?;
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