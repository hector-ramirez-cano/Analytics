
use std::str::FromStr;

use ordered_float::OrderedFloat;

use crate::alerts::AlertPredicateOperation;
use crate::types::MetricValue;

impl AlertPredicateOperation {
    pub fn eval(&self, left: &MetricValue, right: &MetricValue) -> bool {
        match self {
            // arithmetic: allow Integer/Number combinations
            AlertPredicateOperation::MoreThan => match (left, right) {
                (MetricValue::Integer(l), MetricValue::Integer(r)) => l > r,
                (MetricValue::Number(l), MetricValue::Number(r)) => l > r,
                (MetricValue::Integer(l), MetricValue::Number(r)) => (*l as f64) > **r,
                (MetricValue::Number(l), MetricValue::Integer(r)) => *l > OrderedFloat(*r as f64),
                _ => false,
            },
            AlertPredicateOperation::MoreThanEqual => match (left, right) {
                (MetricValue::Integer(l), MetricValue::Integer(r)) => l >= r,
                (MetricValue::Number(l), MetricValue::Number(r)) => l >= r,
                (MetricValue::Integer(l), MetricValue::Number(r)) => (*l as f64) >= **r,
                (MetricValue::Number(l), MetricValue::Integer(r)) => *l >= OrderedFloat(*r as f64),
                _ => false,
            },
            AlertPredicateOperation::LessThan => match (left, right) {
                (MetricValue::Integer(l), MetricValue::Integer(r)) => l < r,
                (MetricValue::Number(l), MetricValue::Number(r)) => l < r,
                (MetricValue::Integer(l), MetricValue::Number(r)) => (*l as f64) < **r,
                (MetricValue::Number(l), MetricValue::Integer(r)) => *l < OrderedFloat(*r as f64),
                _ => false,
            },
            AlertPredicateOperation::LessThanEqual => match (left, right) {
                (MetricValue::Integer(l), MetricValue::Integer(r)) => l <= r,
                (MetricValue::Number(l), MetricValue::Number(r)) => l <= r,
                (MetricValue::Integer(l), MetricValue::Number(r)) => (*l as f64) <= **r,
                (MetricValue::Number(l), MetricValue::Integer(r)) => *l <= OrderedFloat(*r as f64),
                _ => false,
            },

            // equality: all types
            AlertPredicateOperation::Equal => left == right,
            AlertPredicateOperation::NotEqual => left != right,

            // contains: left must be String or Array
            AlertPredicateOperation::Contains => match left {
                MetricValue::String(l_str) => {
                    match right {
                        MetricValue::String(r_str) => return l_str.to_lowercase().contains(&r_str.to_lowercase()),
                        MetricValue::Number(r_f) => return l_str.to_lowercase().contains(&r_f.to_string()),
                        MetricValue::Integer(r_i) => return l_str.to_lowercase().contains(&r_i.to_string()),
                        MetricValue::Boolean(r_b) => return l_str.to_lowercase().contains(&r_b.to_string()),

                        MetricValue::Array(_) 
                        | MetricValue::Null() => {
                            log::error!("[ERROR][RULES] Failed to evaluate contains predicate operation. Right was not 'string', 'number' 'integer' or 'boolean'");
                            return false;
                        }
                    }
                }
                MetricValue::Array(l_arr) => l_arr.contains(right),
                _ => {
                    log::error!("[ERROR][RULES] Failed to evaluate contains predicate operation. Left was not 'string' or 'array'");
                    return false;
                },
            },

            AlertPredicateOperation::Unknown => false,
        }
    }
}

impl std::fmt::Display for AlertPredicateOperation {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            AlertPredicateOperation::MoreThan        => "MORE_THAN",
            AlertPredicateOperation::MoreThanEqual   => "MORE_THAN_EQUAL",
            AlertPredicateOperation::LessThan        => "LESS_THAN",
            AlertPredicateOperation::LessThanEqual   => "LESS_THAN_EQUAL",
            AlertPredicateOperation::Equal           => "EQUAL",
            AlertPredicateOperation::NotEqual        => "NOT_EQUAL",
            AlertPredicateOperation::Contains        => "CONTAINS",
            AlertPredicateOperation::Unknown         => "UNKNOWN",
        };
        write!(f, "{}", s)
    }
}

impl FromStr for AlertPredicateOperation {
    type Err = ();
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "more_than"        => Ok(Self::MoreThan),
            "more_than_equal"  => Ok(Self::MoreThanEqual),
            "less_than"        => Ok(Self::LessThan),
            "less_than_equal"  => Ok(Self::LessThanEqual),
            "equal"            => Ok(Self::Equal),
            "not_equal"        => Ok(Self::NotEqual),
            "contains"         => Ok(Self::Contains),
            _                  => Ok(Self::Unknown),
        }
    }
}
