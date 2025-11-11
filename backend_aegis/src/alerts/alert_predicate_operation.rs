
use std::str::FromStr;

use ordered_float::OrderedFloat;

use crate::alerts::AlertPredicateOperation;
use crate::model::facts::generics::MetricValue;

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

            // contains: right must be String or Array
            AlertPredicateOperation::Contains => match right {
                MetricValue::String(r_str) => {
                    let l_str = left.to_string();
                    r_str.contains(&l_str)
                }
                MetricValue::Array(r_arr) => r_arr.contains(left),
                _ => false,
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
