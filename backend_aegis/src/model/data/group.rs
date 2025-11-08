use std::collections::HashSet;

use serde::{Deserialize, Serialize};

use crate::model::data::device::Device;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Group {
    #[serde(rename = "id")]
    pub group_id: i64,

    pub name: String,
    #[serde(default)]
    
    pub members: Option<Vec<i64>>,
    #[serde(rename = "is-display-group")]

    pub is_display_group: bool,
}

/// The eval result: (any_matched, matched_devices)
pub type EvalResult = (bool, HashSet<Device>);

impl Group {
    pub fn to_map(&self) -> serde_json::Value {
        serde_json::json!({
            "id": self.group_id,
            "name": self.name,
            "is-display-group": self.is_display_group,
            "members": self.members,
        })
    }

    pub fn from_map(v: &serde_json::Value) -> Option<Self> {
        serde_json::from_value(v.clone()).ok()
    }

    // TODO: Renable this
    // Evaluate a rule for every member of the group.
    //
    // Parameters:
    // - rule: reference to an AlertRule
    // - ctx: an arbitrary JSON context passed to the rule (mirrors Python `d: dict`)
    // - get_item_fn: function to resolve an item id -> AnalyticsItem (Device | Link | Group)
    //
    // Returns (any_true, matched_devices_vec)
    /* pub fn eval_rule<F>(&self, rule: &dyn AlertRule, ctx: &serde_json::Value, mut get_item_fn: F) -> EvalResult
    where
        F: FnMut(i64) -> Option<AnalyticsItem>,
    {
        let mut matched: Vec<Device> = Vec::new();

        for &item_id in &self.members {
            if let Some(item) = get_item_fn(item_id) {
                match item {
                    AnalyticsItem::Device(dev) => {
                        // assume Device::eval_rule returns EvalResult as well
                        let (ok, devices) = dev.eval_rule(rule, ctx, &mut get_item_fn);
                        if ok {
                            matched.extend(devices);
                        }
                    }
                    AnalyticsItem::Group(group) => {
                        let (ok, devices) = group.eval_rule(rule, ctx, &mut get_item_fn);
                        if ok {
                            matched.extend(devices);
                        }
                    }
                    AnalyticsItem::Link(link) => {
                        // Links may or may not implement eval_rule semantics;
                        // if you have a Link::eval_rule, call it similarly. For now we skip.
                        let (ok, devices) = link.eval_rule(rule, ctx, &mut get_item_fn);
                        if ok {
                            matched.extend(devices);
                        }
                    }
                }
            }
        }

        let any = !matched.is_empty();
        (any, matched)
    } */
}
