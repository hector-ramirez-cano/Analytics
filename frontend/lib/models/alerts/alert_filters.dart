import 'package:flutter/material.dart';
import 'package:aegis/models/alerts/alert_severity.dart';

class AlertFilters {

  /// Datetime range of alerts to include
  final DateTimeRange range;

  /// Datetime range of ack to include
  final DateTimeRange? ackRange;

  /// Id of the alert to include
  final int? alertId;

  /// Severities that are included
  final Set<AlertSeverity> severities;

  /// Message itself,
  ///  uses LIKE
  final String message;

  /// Actor that Acd'd a message
  final String ackActor;

  /// Id of the target device that triggered the alert
  final int? targetId;

  /// amount of rows to skip from the beningining. Inni the be, inni, inni the beninging
  final int offset;

  /// Whether the message requires acknowledgment to be dismissed
  final bool? requiresAck;


  AlertFilters({
    required this.range,
    required this.ackRange,
    required this.alertId,
    required this.severities,
    required this.message,
    required this.ackActor,
    required this.targetId,
    required this.requiresAck,
    required this.offset,
  });

  factory AlertFilters.empty(DateTimeRange range) {
    return AlertFilters(
      range: range,
      ackRange: null,
      alertId: null,
      severities: AlertSeverity.values.toSet(),
      message: '',
      ackActor: '',
      requiresAck: null,
      targetId: null,
      offset: 0
    );
  }

  AlertFilters copyWith({
    DateTimeRange? range,
    DateTimeRange? ackRange,
    int? alertId,
    Set<AlertSeverity>? severities,
    String? message,
    String? ackActor,
    int? targetId,
    int? offset,
    bool? requiresAck,
  }) {
    return AlertFilters(
      range: range ?? this.range,
      ackRange: ackRange ?? this.ackRange,
      alertId: alertId ?? this.alertId,
      severities: severities ?? this.severities,
      message: message ?? this.message,
      ackActor: ackActor ?? this.ackActor,
      targetId: targetId ?? this.targetId,
      offset: offset ?? this.offset,
      requiresAck: requiresAck ?? this.requiresAck
    );
  }

  AlertFilters clone() {
    return copyWith();
  }

  bool hasSetFilter(AlertSeverity severity) {
    return severities.contains(severity);
  }

  bool setHasFilters<T>() {
    if (T == AlertSeverity) {
      return severities.length != AlertSeverity.values.length;
    }

    throw UnimplementedError("HasFilter called for type with no explicit 'hasFilters' definition");
  }


  AlertFilters applySetFilter(AlertSeverity filter, bool? state) {
    _handleTristateLogic(severities, filter, state);

    // Clone, so a new instance is created and a new 'state' is recognized
    return clone();
  }

    void _handleTristateLogic<T>(Set<T> filterSet, T who, bool? state) {
    if (state == true)  { filterSet.add(who);  return; }
    if (state == false) { filterSet.remove(who); return;}
  }


  AlertFilters toggleFilterClass<T>(bool state) {
    if (T == AlertSeverity) {
      return copyWith(severities: state ? AlertSeverity.values.toSet() : {});
    } else {
      throw UnimplementedError("toggleFilterClass called for type with no explicit 'hasFilters' definition");
    }
  }

    Map<String, dynamic> toDict() {

    final start    = (range.start.millisecondsSinceEpoch / 1000.0);
    final end      = (range.end.millisecondsSinceEpoch   / 1000.0);
    final dict = {};
    if (ackRange != null) {
      final ackStart = (ackRange!.start.millisecondsSinceEpoch / 1000.0);
      final ackEnd   = (ackRange!.end.millisecondsSinceEpoch   / 1000.0);
    
      dict['ack-start'] = ackStart;
      dict['ack-end'] = ackEnd;
    }

    if (alertId != null    ) { dict['alert-id'    ] = alertId    ; }
    if (targetId != null   ) { dict['target-id'   ] = targetId   ; }
    if (message.isNotEmpty ) { dict['message'     ] = message    ; }
    if (ackActor.isNotEmpty) { dict['ack-actor'   ] = ackActor   ; }
    if (requiresAck != null) { dict['requires-ack'] = requiresAck; }
    if (offset != 0)         { dict['offset'      ] = offset     ; }

    return {
      'start': start,
      'end': end,
      'severity': severities.toList().map((val) => val.toString()).toList(),
      ...dict,
    };
  }
} 