use chrono::{DateTime, Utc};

use crate::{alerts::{AlertEvent, AlertSeverity}, types::{AlertRuleId, AlertTargetId}};


impl AlertEvent {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        requires_ack: bool,
        severity: AlertSeverity,
        message: String,
        target_id: AlertTargetId,
        ack_time: Option<DateTime<Utc>>,
        rule_id: AlertRuleId,
        value: String,
        ack_actor: Option<String>,
    ) -> Self {
        let now = Utc::now();
        AlertEvent {
            alert_id: -1,
            alert_time: Some(now),
            ack_time,
            requires_ack,
            severity,
            message,
            target_id,
            ws_notified: false,
            db_notified: false,
            acked: !requires_ack,
            rule_id: Some(rule_id),
            ack_actor,
            value,

        }
    }

    /// Convert to dictionary-like JSON value
    pub fn to_dict(&self, stringify: bool) -> serde_json::Value {
        let mut map = serde_json::Map::new();

        map.insert("alert-id".into(), serde_json::json!(self.alert_id));
        map.insert(
            "alert-time".into(),
            serde_json::json!(self.alert_time.map(|t| t.timestamp())),
        );
        map.insert(
            "ack-time".into(),
            serde_json::json!(self.ack_time.map(|t| t.timestamp())),
        );
        map.insert("requires-ack".into(), serde_json::json!(self.requires_ack));

        if stringify {
            map.insert("severity".into(), serde_json::json!(self.severity.to_string()));
        } else {
            map.insert("severity".into(), serde_json::to_value(self.severity).unwrap_or(serde_json::Value::String("".to_string())));
        }

        map.insert("message".into(), serde_json::json!(self.message));
        map.insert("target-id".into(), serde_json::json!(self.target_id));
        map.insert("acked".into(), serde_json::json!(self.acked));
        map.insert("value".into(), serde_json::json!(self.value));

        serde_json::Value::Object(map)
    }
}

impl std::fmt::Display for AlertEvent {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let mut dict = self.to_dict(true);
        // force severity stringified
        if let Some(sev) = dict.get_mut("severity") {
            *sev = serde_json::json!(self.severity.to_string());
        }
        write!(f, "{}", dict)
    }
}
