#[cfg(test)]
mod alert_backend_tests {
    use std::{collections::{HashMap, HashSet}, time::Duration};

    use sqlx::{Pool, Postgres};

    use crate::{alerts::{AlertPredicateOperation, AlertReduceLogic, AlertRule, AlertRuleKind, AlertSeverity, EvaluableItem, OperandModifier, alert_backend::AlertBackend}, model::{data::{device::Device, device_state::DeviceStatus}, db::pools::init_posgres_pool, facts::{fact_gathering_backend::{DeviceFacts, FactMessage}, icmp::icmp_status::IcmpStatus}}, types::MetricValue};

    #[tokio::test]
    pub async fn test_simple_alert_rules() {
        let dataset : FactMessage = HashMap::from([
            (
                "10.0.0.1".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_rtt".to_string(),
                            MetricValue::Number(74.58.into())
                        ),
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Reachable".to_string())
                        ),
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Reachable),
                    exposed_fields: HashSet::from(["icmp_rtt".to_string(), "icmp_status".to_string()])
                }
            )
        ]);

        let device : Device = serde_json::from_value(serde_json::json!({
            "id": 10,
            "name": "Testing Device",
            "latitude": 0.0,
            "longitude": 0.0,
            "management-hostname": "10.0.0.1",
            "configuration": {
                "data-sources": ["icmp"],
                "available-values": ["icmp_rtt"],
                "requested-metadata": [],
                "requested-metrics": []
            }
        })).expect("Definition should be valid");
        let device = EvaluableItem::Device(device);

        let rule_right_75 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - right 75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [{
                "left": "&icmp_rtt",
                "op": "more_than",
                "right": 75,
            }]
        });

        let rule_right_0 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - right 0",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [{
                "left": "&icmp_rtt",
                "op": "more_than",
                "right": 0,
            }]
        });

        let rule_left_80_right_ref = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - left 80 right &icmp_rtt",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [{
                "left": 80,
                "op": "more_than",
                "right": "&icmp_rtt",
            }]
        });

        let rule_two_predicates_both_75 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - 2 predicates both >75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                },
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75.5,
                }
            ]
        });

        let rule_two_predicates_both_75_inverted = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - 2 predicates both >75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                },
                {
                    "left": 75,
                    "op": "less_than",
                    "right": "&icmp_rtt",
                }
            ]
        });

        let rule_any_75_and_20 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Any: >75 and 20",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                },
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 20,
                }
            ]
        });

        let rule_any_20_and_75 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Any: 20 and >75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 20,
                },
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                }
            ]
        });
        
        let rule_any_both_75 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Any: both >75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                },
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                }
            ]
        });

        let rule_multiple_metrics = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Multiple metrics",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [{
                "left": "&icmp_rtt",
                "op": "more_than",
                "right": 70,
            },
            {
                "left": "&icmp_status",
                "op": "equal",
                "right": "Reachable",
            }]
        });

        let rule_any_multiple_metrics = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Multiple metrics",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [{
                "left": "&icmp_rtt",
                "op": "more_than",
                "right": 75,
            },
            {
                "left": "&icmp_status",
                "op": "equal",
                "right": "Reachable",
            }]
        });
        println!("{}", rule_any_multiple_metrics);


        let rule1: AlertRule = serde_json::from_value(rule_right_75                         ).expect("Definition should be valid"); // FALSE
        let rule2: AlertRule = serde_json::from_value(rule_right_0                          ).expect("Definition should be valid"); // TRUE
        let rule3: AlertRule = serde_json::from_value(rule_left_80_right_ref                ).expect("Definition should be valid"); // TRUE
        let rule4: AlertRule = serde_json::from_value(rule_two_predicates_both_75           ).expect("Definition should be valid"); // FALSE
        let rule5: AlertRule = serde_json::from_value(rule_two_predicates_both_75_inverted  ).expect("Definition should be valid"); // FALSE
        let rule6: AlertRule = serde_json::from_value(rule_any_75_and_20                    ).expect("Definition should be valid"); // TRUE - 1
        let rule7: AlertRule = serde_json::from_value(rule_any_20_and_75                    ).expect("Definition should be valid"); // TRUE - 1
        let rule8: AlertRule = serde_json::from_value(rule_any_both_75                      ).expect("Definition should be valid"); // FALSE
        let rule9: AlertRule = serde_json::from_value(rule_multiple_metrics                 ).expect("Definition should be valid"); // TRUE
        let rulea: AlertRule = serde_json::from_value(rule_any_multiple_metrics             ).expect("Definition should be valid"); // TRUE
        
        assert!(device.clone().eval(&rule1, &dataset, &dataset).await.is_none()); // FALSE
        assert!(device.clone().eval(&rule2, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule3, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule4, &dataset, &dataset).await.is_none()); // FALSE
        assert!(device.clone().eval(&rule5, &dataset, &dataset).await.is_none()); // FALSE
        assert!(device.clone().eval(&rule6, &dataset, &dataset).await.is_some()); // TRUE - 1
        assert!(device.clone().eval(&rule7, &dataset, &dataset).await.is_some()); // TRUE - 1
        assert!(device.clone().eval(&rule8, &dataset, &dataset).await.is_none()); // FALSE
        assert!(device.clone().eval(&rule9, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rulea, &dataset, &dataset).await.is_some()); // TRUE
    }

    #[tokio::test]
    pub async fn test_delta_alert_rules() {
        let dataset_a : FactMessage = HashMap::from([
            (
                "10.0.0.1".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Reachable".to_string())
                        )
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Reachable),
                    exposed_fields: HashSet::from(["icmp_status".to_string()])
                }
            )
        ]);

        let dataset_b : FactMessage = HashMap::from([
            (
                "10.0.0.1".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Unreachable".to_string())
                        )
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Unreachable("".to_string())),
                    exposed_fields: HashSet::from(["icmp_status".to_string()])
                }
            )
        ]);

        let device : Device = serde_json::from_value(serde_json::json!({
            "id": 10,
            "name": "Testing Device",
            "latitude": 0.0,
            "longitude": 0.0,
            "management-hostname": "10.0.0.1",
            "configuration": {
                "data-sources": ["icmp"],
                "available-values": ["icmp_status"],
                "requested-metadata": [],
                "requested-metrics": []
            }
        })).expect("Definition should be valid");
        let device = EvaluableItem::Device(device);

        let rule_delta = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Multiple metrics",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "delta",
            "data-source": "facts",
            "predicates": [{
                "left": "&icmp_status",
                "op": "not_equal",
                "right": "&icmp_status",
            },
            {
                "left": "Unreachable",
                "op": "equal",
                "right": "&icmp_status",
            }]
        });

        let rule1: AlertRule = serde_json::from_value(rule_delta).expect("Definition should be valid");

        assert!(device.clone().eval(&rule1, &dataset_a, &dataset_b).await.is_some()); // TRUE, it changed
        assert!(device.clone().eval(&rule1, &dataset_a, &dataset_a).await.is_none()); // FALSE
        assert!(device.clone().eval(&rule1, &dataset_b, &dataset_b).await.is_none()); // FALSE

        

    }

    #[tokio::test]
    pub async fn test_sustained_rules() {

        let postgres_pool : Pool<Postgres> = init_posgres_pool().await.unwrap();
        AlertBackend::init(&postgres_pool).await;

        let dataset_reachable : FactMessage = HashMap::from([
            (
                "10.0.0.1".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_rtt".to_string(),
                            MetricValue::Number(74.58.into())
                        ),
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Reachable".to_string())
                        ),
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Reachable),
                    exposed_fields: HashSet::from(["icmp_rtt".to_string(), "icmp_status".to_string()])
                },
            ),
            (
                "10.0.0.2".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Reachable".to_string())
                        ),
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Reachable),
                    exposed_fields: HashSet::from(["icmp_rtt".to_string(), "icmp_status".to_string()])
                }
            )
        ]);

        let dataset_unreachable : FactMessage = HashMap::from([
            (
                "10.0.0.1".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_rtt".to_string(),
                            MetricValue::Number(74.58.into())
                        ),
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Unreachable".to_string())
                        ),
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Unreachable("".to_string())),
                    exposed_fields: HashSet::from(["icmp_rtt".to_string(), "icmp_status".to_string()])
                }
            ),
            (
                "10.0.0.2".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Unreachable".to_string())
                        ),
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Reachable),
                    exposed_fields: HashSet::from(["icmp_rtt".to_string(), "icmp_status".to_string()])
                }
            )
        ]);

        let device : Device = serde_json::from_value(serde_json::json!({
            "id": 10,
            "name": "Testing Device Sustained",
            "latitude": 0.0,
            "longitude": 0.0,
            "management-hostname": "10.0.0.1",
            "configuration": {
                "data-sources": ["icmp"],
                "available-values": ["icmp_status"],
                "requested-metadata": [],
                "requested-metrics": []
            }
        })).expect("Definition should be valid");
        let device1 = EvaluableItem::Device(device);

        let device2 : Device = serde_json::from_value(serde_json::json!({
            "id": 12,
            "name": "Testing Device Interrupted",
            "latitude": 0.0,
            "longitude": 0.0,
            "management-hostname": "10.0.0.2",
            "configuration": {
                "data-sources": ["icmp"],
                "available-values": ["icmp_status"],
                "requested-metadata": [],
                "requested-metrics": []
            }
        })).expect("Definition should be valid");
        let device2 = EvaluableItem::Device(device2);

        let rule_delta = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Multiple metrics",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": AlertRuleKind::Sustained { seconds: 2 },
            "data-source": "facts",
            "predicates": [{
                "left": "&icmp_status",
                "op": "equal",
                "right": "Unreachable",
            }]
        });
        println!("{}", rule_delta);
        let rule_sustained   : AlertRule  = serde_json::from_value(rule_delta.clone()).expect("Rule should be valid");
        let rule_interrupted : AlertRule  = serde_json::from_value(rule_delta.clone()).expect("Rule should be valid");

        // Initial evaluation to TRUE
        assert!(device1.clone().eval(&rule_sustained  , &dataset_unreachable, &dataset_unreachable).await.is_none()); // First raised
        assert!(device2.clone().eval(&rule_interrupted, &dataset_unreachable, &dataset_unreachable).await.is_none()); // First raised
        
        tokio::time::sleep(Duration::from_millis(200)).await;
        
        // device2 comes up online
        assert!(device1.clone().eval(&rule_sustained  , &dataset_unreachable, &dataset_unreachable).await.is_none()); // Not yet, 200ms passed
        assert!(device2.clone().eval(&rule_interrupted, &dataset_reachable  , &dataset_reachable  ).await.is_none()); // Reset

        tokio::time::sleep(Duration::from_millis(750)).await;

        // device2 comes back down
        assert!(device1.clone().eval(&rule_sustained  , &dataset_unreachable, &dataset_unreachable).await.is_none()); // Not yet, 950ms passed
        assert!(device2.clone().eval(&rule_interrupted, &dataset_unreachable, &dataset_unreachable).await.is_none()); // First raised
        
        tokio::time::sleep(Duration::from_millis(1200)).await;

        // Enough time has passed to cause a trigger for device 1, as it hasn't come online
        // device2 is down, but not enough uninterrupted time has passed, so it still doesn't raise
        assert!(device1.clone().eval(&rule_sustained  , &dataset_unreachable, &dataset_unreachable).await.is_some()); // TRUE, it triggered after 2150ms
        assert!(device2.clone().eval(&rule_interrupted, &dataset_unreachable, &dataset_unreachable).await.is_none()); // Not yet, 1200ms passed
        
        
        tokio::time::sleep(Duration::from_millis(950)).await;

        // Enough time has passed to cause a trigger for device 2, as it hasn't come online
        // Devie 1 doesn't raise again, as the timer is reset
        assert!(device1.clone().eval(&rule_sustained  , &dataset_unreachable, &dataset_unreachable).await.is_none()); // Not triggered, 950ms passed since last
        assert!(device2.clone().eval(&rule_interrupted, &dataset_unreachable, &dataset_unreachable).await.is_some()); // TRUE, it triggered

        // TODO: DEBOUNCE

    }

    #[tokio::test]
    pub async fn test_simple_alert_rules_modifiers() {
        let dataset : FactMessage = HashMap::from([
            (
                "10.0.0.1".to_string(),
                DeviceFacts {
                    metrics: HashMap::from([
                        (
                            "icmp_rtt".to_string(),
                            MetricValue::Number(74.58.into())
                        ),
                        (
                            "icmp_status".to_string(),
                            MetricValue::String("Unreachable".to_string())
                        ),
                    ]),
                    status: DeviceStatus::new_icmp(IcmpStatus::Reachable),
                    exposed_fields: HashSet::from(["icmp_rtt".to_string(), "icmp_status".to_string()])
                }
            )
        ]);

        let device : Device = serde_json::from_value(serde_json::json!({
            "id": 10,
            "name": "Testing Device",
            "latitude": 0.0,
            "longitude": 0.0,
            "management-hostname": "10.0.0.1",
            "configuration": {
                "data-sources": ["icmp"],
                "available-values": ["icmp_rtt"],
                "requested-metadata": [],
                "requested-metrics": []
            }
        })).expect("Definition should be valid");
        let device = EvaluableItem::Device(device);

        let rule_right_75 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - right 75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": AlertRuleKind::Simple,
            "data-source": "facts",
            "predicates": [{
                "left-modifier": OperandModifier::Add(10.0),
                "left": "&icmp_rtt",
                "op": "more_than",
                "right": 75,
            }]
        });

        let rule_right_0 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - right 0",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [{
                "left-modifier": OperandModifier::Mul(0.5),
                "left": "&icmp_rtt",
                "op": "more_than",
                "right": 0,
            }]
        });

        let rule_left_80_right_ref = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - left 80 right &icmp_rtt",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [{
                "left-operand": OperandModifier::Add(50.0),
                "left": 80,
                "op": "more_than",
                "right": "&icmp_rtt",
                "right-operand": OperandModifier::Add(50.0)
            }]
        });

        let rule_two_predicates_both_75 = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - 2 predicates both >75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left-operand": OperandModifier::Add(10.0),
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                    "right-operand": OperandModifier::Add(10.0),
                },
                {
                    "left-operand": OperandModifier::Add(10.0),
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75.5,
                    "right-operand": OperandModifier::Add(10.0),
                }
            ]
        });

        let rule_one_predicate_with_mul = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - 2 predicates both >75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 60,
                    "right-modifier": OperandModifier::Mul(1.2) 
                },
                
            ]
        });

        let rule_mult_and_add = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Any: >75 and 20",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left-modifier": OperandModifier::Mul(1.8),
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                    "right-modifier": OperandModifier::Add(55.0)
                }
            ]
        });

        let rule_barely_false_with_mul_and_add = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Any: 20 and >75",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left-modifier": OperandModifier::Mul(1.7),
                    "left": "&icmp_rtt",
                    "op": "more_than",
                    "right": 75,
                    "right-modifier": OperandModifier::Add(55.0)
                }
            ]
        });
        
        let rule_string_append = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - append",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_status",
                    "op": "equal",
                    "right": "Unreach",
                    "right-modifier": OperandModifier::Append("able".to_string())
                }
            ]
        });

        let rule_string_prepend = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Prepend",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_status",
                    "op": "equal",
                    "right": "reachable",
                    "right-modifier": OperandModifier::Prepend("Un".to_string())
                }
            ]
        });

        let rule_string_trim = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Trim",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_status",
                    "op": "equal",
                    "right": "    Unreachable     ",
                    "right-modifier": OperandModifier::Trim
                }
            ]
        });

        let rule_string_replace = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Replace",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_status",
                    "op": "equal",
                    "right": "=Unreachable=",
                    "right-modifier": OperandModifier::Replace{ pattern: "=".to_string(), with: "".to_string()}
                }
            ]
        });

        let rule_string_replace_n = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Replace N",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_status",
                    "op": "equal",
                    "right": "=Unreachable=",
                    "right-modifier": OperandModifier::ReplaceN { pattern: "=".to_string(), with: "".to_string(), count: 1}
                }
            ]
        });

        let modifier = OperandModifier::Multi {
            operations: vec![
                OperandModifier::ReplaceN { 
                    pattern: "=".to_string(),
                    with: "".to_string(),
                    count: 1
                },
                OperandModifier::ReplaceN { 
                    pattern: "=".to_string(),
                    with: "".to_string(),
                    count: 1
                },
                OperandModifier::Lower,
                OperandModifier::Prepend("Un".to_string()),
                OperandModifier::Trim,
                OperandModifier::Append("able".to_string())
            ],
        };
        let rule_string_multi = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Prepend",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::Any,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left": "&icmp_status",
                    "op": "not_equal",
                    "right": "  =REACH=  ",
                    "right-modifier": modifier
                }
            ]
        });

        let complex_modifier = OperandModifier::Multi {
            operations: vec![
                OperandModifier::Add(-20.0),
                OperandModifier::Mul(0.95),
                OperandModifier::Rem(20.0),
                OperandModifier::Add(5.5),
                OperandModifier::Mod(15),
                OperandModifier::Pow(1.5)
            ]
        };

        let rule_complex_modifier = serde_json::json!({
            "id": 1,
            "name": "TEST RULE - Prepend",
            "requires-ack": true,
            "severity": AlertSeverity::Debug,
            "target": 10,
            "reduce-logic": AlertReduceLogic::All,
            "rule-type": "simple",
            "data-source": "facts",
            "predicates": [
                {
                    "left-modifier": complex_modifier.clone(),
                    "left": "&icmp_rtt",
                    "op": AlertPredicateOperation::MoreThan,
                    "right": 2.8,
                },
                {
                    "left-modifier": complex_modifier.clone(),
                    "left": "&icmp_rtt",
                    "op": AlertPredicateOperation::LessThan,
                    "right": 3,
                }
            ]
        });

        
        println!("{}", serde_json::json!(rule_string_multi));
        println!("{}", serde_json::json!(rule_complex_modifier));

        let rule1: AlertRule = serde_json::from_value(rule_right_75                         ).expect("Definition should be valid"); // TRUE
        let rule2: AlertRule = serde_json::from_value(rule_right_0                          ).expect("Definition should be valid"); // TRUE
        let rule3: AlertRule = serde_json::from_value(rule_left_80_right_ref                ).expect("Definition should be valid"); // TRUE
        let rule4: AlertRule = serde_json::from_value(rule_two_predicates_both_75           ).expect("Definition should be valid"); // FALSE
        let rule5: AlertRule = serde_json::from_value(rule_one_predicate_with_mul           ).expect("Definition should be valid"); // TRUE
        let rule6: AlertRule = serde_json::from_value(rule_mult_and_add                     ).expect("Definition should be valid"); // TRUE
        let rule7: AlertRule = serde_json::from_value(rule_barely_false_with_mul_and_add    ).expect("Definition should be valid"); // FALSE
        let rule8: AlertRule = serde_json::from_value(rule_string_append                    ).expect("Definition should be valid"); // TRUE
        let rule9: AlertRule = serde_json::from_value(rule_string_prepend                   ).expect("Definition should be valid"); // TRUE
        let rulea: AlertRule = serde_json::from_value(rule_string_trim                      ).expect("Definition should be valid"); // TRUE
        let ruleb: AlertRule = serde_json::from_value(rule_string_replace                   ).expect("Definition should be valid"); // TRUE
        let rulec: AlertRule = serde_json::from_value(rule_string_replace_n                 ).expect("Definition should be valid"); // FALSE
        let ruled: AlertRule = serde_json::from_value(rule_string_multi                     ).expect("Definition should be valid"); // TRUE
        let rulee: AlertRule = serde_json::from_value(rule_complex_modifier                 ).expect("Definition should be valid"); // TRUE
        
        assert!(device.clone().eval(&rule1, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule2, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule3, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule4, &dataset, &dataset).await.is_none()); // FALSE
        assert!(device.clone().eval(&rule5, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule6, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule7, &dataset, &dataset).await.is_none()); // FALSE
        assert!(device.clone().eval(&rule8, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rule9, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rulea, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&ruleb, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rulec, &dataset, &dataset).await.is_none()); // FALSE
        assert!(device.clone().eval(&ruled, &dataset, &dataset).await.is_some()); // TRUE
        assert!(device.clone().eval(&rulee, &dataset, &dataset).await.is_some()); // TRUE
    }

}