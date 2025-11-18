
import 'package:flutter/material.dart';
import 'package:aegis/models/syslog/syslog_facility.dart';
import 'package:aegis/models/syslog/syslog_severity.dart';

class SyslogFilters {
  /// Datetime range of syslog messages to include
  final DateTimeRange range;
  
  /// Facilities that are included
  final Set<SyslogFacility> facilities;

  /// Severities that are included
  final Set<SyslogSeverity> severities;

  /// Hostname of origin
  final String origin;

  /// PID of the message
  final String pid;

  /// Message itself, uses FTS
  final String message;

  /// amount of rows to skip from the beningining. Inni, inni the beninging
  final int offset;

  SyslogFilters({
    required this.range,
    required this.facilities,
    required this.severities,
    required this.origin,
    required this.pid,
    required this.message,
    required this.offset,
  });

  factory SyslogFilters.empty(DateTimeRange range) {
    return SyslogFilters(
      range: range,
      facilities: SyslogFacility.values.toSet(),
      severities: SyslogSeverity.values.toSet(),
      origin: "",
      pid: "",
      message: "",
      offset: 0,
    );
  }

  SyslogFilters copyWith({
    DateTimeRange? range,
    Set<SyslogFacility>? facilities,
    Set<SyslogSeverity>? severities,
    String? origin,
    String? pid,
    String? message,
    int? offset,
  }) {
    return SyslogFilters(
      range: range ?? this.range,
      facilities: Set.from(facilities ?? this.facilities),
      severities: Set.from(severities ?? this.severities),
      origin: origin ?? this.origin,
      pid: pid ?? this.pid,
      message: message ?? this.message,
      offset: offset ?? this.offset,
    );
  }

  SyslogFilters clone() {
    return SyslogFilters(
      range: range,
      facilities: Set.from(facilities),
      severities: Set.from(severities),
      origin: origin,
      pid: pid,
      message: message,
      offset: offset
    );
  }

  bool hasSetFilter(dynamic filter) {
    return [facilities, severities].any((filterSet) => filterSet.contains(filter));
  }

  bool setHasFilters<T>() {
    if (T == SyslogFacility) {
      return facilities.length != SyslogFacility.values.length;
    }
    if (T == SyslogSeverity) {
      return severities.length != SyslogSeverity.values.length;
    }

    throw UnimplementedError("HasFilter called for type with no explicit 'hasFilters' definition");
  }

  SyslogFilters applySetFilter(dynamic filter, bool? state) {
    if (filter is SyslogFacility) {
      _handleTristateLogic(facilities, filter, state);
    } else if (filter is SyslogSeverity) {
      _handleTristateLogic(severities, filter, state);
    }

    // Clone, so a new instance is created and a new "state" is recognized
    return clone();
  }

  SyslogFilters toggleFilterClass<T>(bool state) {
    if (T == SyslogFacility) {
      return copyWith(facilities: state ? SyslogFacility.values.toSet() : {});
    } else if (T == SyslogSeverity) {
      return copyWith(severities: state ? SyslogSeverity.values.toSet() : {});
    } else {
      throw UnimplementedError("toggleFilterClass called for type with no explicit 'hasFilters' definition");
    }
  }


  String filterStrings<T>() {
    if (!setHasFilters<T>()) { return ""; }

    return "[FILTRADO]";
  }

  void _handleTristateLogic<T>(Set<T> filterSet, T who, bool? state) {
    if (state == true)  { filterSet.add(who);  return; }
    if (state == false) { filterSet.remove(who); return;}
  }

  Map<String, dynamic> toDict() {

    final start = (range.start.millisecondsSinceEpoch / 1000.0);
    final end =   (range.end.millisecondsSinceEpoch   / 1000.0);
    return {
      'start': start,
      'end': end,
      'facility': facilities.toList().map((val) => val.toString()).toList(),
      'severity': severities.toList().map((val) => val.toString()).toList(),
      'message' : message,
      'origin'  : origin,
      'offset': offset,
      'pid': pid,
    };
  }
}
