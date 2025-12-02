use std::fmt;

use ordered_float::Pow;

use crate::{alerts::OperandModifier, types::MetricValue};


impl OperandModifier {

    pub fn eval(&self, value: Option<&MetricValue>) -> Option<MetricValue> {
        let value = value?;

        match self {
            OperandModifier::None => return Some(value.clone()),
            OperandModifier::Multi { first, then } => {
                return then.eval(first.eval(Some(value)).as_ref())
            }
            _ => {}
        };
        
        match value {
            MetricValue::String(s) => {
                match self {
                    // Always valid. It shoult never reach this arm, but just in case
                    OperandModifier::None => return Some(value.clone()),
                    OperandModifier::Multi{first, then} => return then.eval(first.eval(Some(value)).as_ref()),

                    // Valid String operations
                    OperandModifier::Append(t) => return Some(MetricValue::String(format!("{}{}", s, t).to_owned())),
                    OperandModifier::Prepend(t) => return Some(MetricValue::String(format!("{}{}", t, s).to_owned())),
                    OperandModifier::Trim => return Some(MetricValue::String(s.trim().to_string())),
                    OperandModifier::Lower => return Some(MetricValue::String(s.to_lowercase())),
                    OperandModifier::Upper => return Some(MetricValue::String(s.to_uppercase())),
                    OperandModifier::Replace{pattern, with} => Some(MetricValue::String(s.replace(pattern, with))),
                    OperandModifier::ReplaceN{pattern, with, count} => Some(MetricValue::String(s.replacen(pattern, with, *count))),
                    
                    // Arithmetic operations. Show error and return unchanged
                    OperandModifier::Add(_)
                    | OperandModifier::Rem(_)
                    | OperandModifier::Pow(_)
                    | OperandModifier::Mod(_)
                    | OperandModifier::Mul(_) => {
                        log::error!("[ERROR][ALERTS][RULES] Tried to apply arithmetic operand modifier to String Metric.");
                        log::warn!("^ This item will be skipped from modification");
                        return Some(value.clone())
                    },
                }
            },
            
            MetricValue::Number(n) => {
                match self {
                    // Always valid. It shoult never reach this arm, but just in case
                    OperandModifier::None => return Some(value.clone()),
                    OperandModifier::Multi{first, then} => return then.eval(first.eval(Some(value)).as_ref()),

                    // Valid Arithmetic operations.
                    OperandModifier::Add(f) =>  return Some(MetricValue::Number(n+f)),
                    OperandModifier::Mul(f) => return Some(MetricValue::Number(n*f)),
                    OperandModifier::Rem(den) => return Some(MetricValue::Number(n % den)),
                    OperandModifier::Mod(den) => return Some(MetricValue::Integer(n.0 as i64 % den)),
                    OperandModifier::Pow(exp) => return Some(MetricValue::Number(n.pow(exp))),
                    
                    // String operations. Show error and return unchanged
                    OperandModifier::Prepend(_)
                    | OperandModifier::Trim
                    | OperandModifier::Lower
                    | OperandModifier::Upper
                    | OperandModifier::Replace{..}
                    | OperandModifier::ReplaceN{..}
                    | OperandModifier::Append(_) => {
                        log::error!("[ERROR][ALERTS][RULES] Tried to apply String operand modifier to Numeric Metric.");
                        log::warn!("^ This item will be skipped from modification");
                        return Some(value.clone())
                    }
                    
                }
            },
            MetricValue::Integer(n) =>
            match self {
                    // Always valid. It shoult never reach this arm, but just in case
                    OperandModifier::None => return Some(value.clone()),
                    OperandModifier::Multi{first, then} => return then.eval(first.eval(Some(value)).as_ref()),

                    // Valid Arithmetic operations.
                    OperandModifier::Add(f) => return Some(MetricValue::Number((f+(*n as f64)).into())),
                    OperandModifier::Mul(f) => return Some(MetricValue::Number((f*(*n as f64)).into())),
                    OperandModifier::Rem(den) => return Some(MetricValue::Number(((*n as f64) % den).into())),
                    OperandModifier::Mod(den) => return Some(MetricValue::Integer(n % den)),
                    OperandModifier::Pow(exp) => return Some(MetricValue::Number((*n as f64).pow(exp).into())),

                    OperandModifier::Prepend(_)
                    | OperandModifier::Lower
                    | OperandModifier::Upper
                    | OperandModifier::Replace{..}
                    | OperandModifier::ReplaceN{..}
                    | OperandModifier::Trim
                    | OperandModifier::Append(_) => {
                        log::error!("[ERROR][ALERTS][RULES] Tried to apply String operand modifier to Numeric Metric.");
                        log::warn!("^ This item will be skipped from modification");
                        return Some(value.clone())
                    }
                },

            MetricValue::Boolean(_)
            | MetricValue::Null()
            | MetricValue::Array(_) => {
                log::error!("[ERROR][ALERTS][RULES] Tried to apply operand modifier to non-modifiable value. Actual metric: {}", value);
                log::warn!("^ This item will be skipped from modification");
                return Some(value.clone())
            },
        }
    }
}


impl fmt::Display for OperandModifier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            OperandModifier::Add(v) => write!(f, "add({})", v),
            OperandModifier::Mul(v) => write!(f, "mul({})", v),
            OperandModifier::Append(s) => write!(f, "append('{}')", s),
            OperandModifier::Prepend(suf) => write!(f, "preppend('{}')", suf),
            OperandModifier::None => write!(f, "()"),
            OperandModifier::Mod(den) => write!(f, "mod({})", den),
            OperandModifier::Rem(den) => write!(f, "rem({})", den),
            OperandModifier::Pow(exp) => write!(f, "pow({})", exp),
            OperandModifier::Trim => write!(f, "trim()"),
            OperandModifier::Lower => write!(f, "lower()"),
            OperandModifier::Upper => write!(f, "upper()"),
            OperandModifier::Replace{pattern, with} => write!(f, "replace('{}', with='{}')", pattern, with),
            OperandModifier::ReplaceN{pattern, with, count} => write!(f, "replace('{}', with='{}', count={})", pattern, with, count),
            OperandModifier::Multi {first, then} => write!(f, "{}.{}", first, then),
        }
    }
}