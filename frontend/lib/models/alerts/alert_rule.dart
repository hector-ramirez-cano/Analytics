import 'dart:math';

import 'package:aegis/models/alerts/alert_predicate.dart';
import 'package:aegis/models/alerts/alert_reduce_logic.dart';
import 'package:aegis/models/alerts/alert_severity.dart';
import 'package:aegis/models/alerts/alert_source.dart';
import 'package:aegis/models/analytics_item.dart';
import 'package:aegis/services/alerts/alert_rules_service.dart';

class AlertRule extends AnalyticsItem<AlertRule> {
  const AlertRule({
    required super.id,
    required this.name,
    required this.requiresAck,
    required this.reduceLogic,
    required this.source,
    required this.targetId,
    required this.severity,
    required this.definition,
  });

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      id: json["id"],
      name: json["name"],
      requiresAck: json["requires-ack"],
      reduceLogic: AlertReduceLogic.fromString(json["reduce-logic"] ?? ""),
      source: AlertSource.fromString(json["data-source"] ?? ""),
      targetId: json["target"],
      severity: AlertSeverity.fromString(json["severity"]),
      definition: AlertPredicate.listFromJson(json["predicates"])
    );
  }

  final List<AlertPredicate> definition;
  final String name;
  final AlertReduceLogic reduceLogic;
  final bool requiresAck;
  final AlertSeverity severity;
  final AlertSource source;
  final int targetId;

  @override
  bool isNewItem() {
    return id < 0;
  }

  @override
  AlertRule mergeWith(AlertRule other) {
    Set<AlertPredicate> definition = Set.from(other.definition)..addAll(this.definition);

    return copyWith(definition: definition.toList());
  }

  AlertRule copyWith({
    int? id,
    String? name,
    bool? requiresAck,
    AlertReduceLogic? reduceLogic,
    List<AlertPredicate>? definition,
    AlertSource? source,
    int? targetId,
    AlertSeverity? severity,
  }) {
    return AlertRule(
      id: id ?? this.id,
      name: name ?? this.name,
      requiresAck: requiresAck ?? this.requiresAck,
      reduceLogic: reduceLogic ?? this.reduceLogic,
      definition: definition ?? this.definition,
      source: source ?? this.source,
      targetId: targetId ?? this.targetId,
      severity: severity ?? this.severity,
    );
  }

  factory AlertRule.empty() {
    return AlertRule(
      id: -1*Random(2).nextInt(10000),
      name: "Nueva regla",
      requiresAck: false,
      reduceLogic: AlertReduceLogic.unknown,
      source: AlertSource.unknown,
      targetId: -1,
      severity: AlertSeverity.unknown,
      definition: []
    );
  }

  bool isModifiedName(AlertRuleSet ruleSet) {
    return ruleSet.rules[id]?.name != name;
  }

  Map<String, dynamic> ruleDefinitionToMap() {
    return {
      "severity": severity.toString(),
      "target": targetId,
      "reduce-logic": reduceLogic.toString(),
      "data-source": source.toString(),
      "kind": "simple",
      "predicates": definition.map((predicate) => predicate.toMap()).toList()
    };
  }

  Map<String, dynamic> toMap() {
    return {
      "id" : id,
      "name": name,
      "requires-ack": requiresAck,
      "rule-definition": ruleDefinitionToMap(),
      "kind": "simple", // TODO: Locked as simple until this gets added to the frontend
      "data-source": source.toString()
    };
  }
}