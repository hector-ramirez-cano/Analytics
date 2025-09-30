
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';
import 'package:network_analytics/models/syslog/syslog_severity.dart';

enum SyslogTableCacheState {
  created, 
  updating,
  hydrated,
}

class SyslogFilters {
  final Set<SyslogFacility> facilities;
  final Set<SyslogSeverity> severities;
  final String origin;
  final String pid;
  final String message;

  SyslogFilters({
    required this.facilities,
    required this.severities,
    required this.origin,
    required this.pid,
    required this.message,
  });

  factory SyslogFilters.empty() {
    return SyslogFilters(
      facilities: SyslogFacility.values.toSet(),
      severities: SyslogSeverity.values.toSet(),
      origin: "",
      pid: "",
      message: "",
    );
  }

  SyslogFilters copyWith({
    Set<SyslogFacility>? facilities,
    Set<SyslogSeverity>? severities,
    String? origin,
    String? pid,
    String? message,
  }) {
    return SyslogFilters(
      facilities: Set.from(facilities ?? this.facilities),
      severities: Set.from(severities ?? this.severities),
      origin: origin ?? this.origin,
      pid: pid ?? this.pid,
      message: message ?? this.message,
    );
  }

  SyslogFilters clone() {
    return SyslogFilters(
      facilities: Set.from(facilities),
      severities: Set.from(severities),
      origin: origin,
      pid: pid,
      message: message,
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
    }

    return clone();
  }


  String filterStrings<T>() {
    if (!setHasFilters<T>()) { return ""; }

    return "[FILTRADO]";
  }

  void _handleTristateLogic<T>(Set<T> filterSet, T who, bool? state) {
    if (state == true)  { filterSet.add(who);  return; }
    if (state == false) { filterSet.remove(who); return;}
  }
}

class SyslogTableCache {
  /// Datetime range held within this cache
  final DateTimeRange range;

  /// Count of recorded messages in the timeframe, given first before any other message
  /// Helps the caller know how many rows to expect before streaming begins
  final int messageCount;

  /// Actual mapping of messages, using the ID column on the SQLite DB, given as first parameter of the `SELECT * FROM SystemEvents;`
  final Map<int, SyslogMessage> messages;

  /// Mapping of rows -> message ID, such that the position in the list represents the position in the tableView, and the held value
  /// is the ID column on the SQLite DB, as timeranges will most likely contain messages at the first position, that are not the first ID.
  final Map<int, int> rowMapping;

  /// Mapping of message ID -> row Index
  final Map<int, int> messageMapping;

  /// List of ordered rows (without ID) -> messageID, that holds the rows that were updated most recently, such that the caller knows which rows have hydrated data
  final List<int> hydratedRows;

  /// Holds a queue of rows by index that have been reserved, and currently show a shimmering effect
  final Queue<int> reservedRows;

  /// Holds the number of rows requested from the database backend, used for tracking how many shimmer rows should be created
  final int requestedCount;

  /// Holds the state of the table, regarding whether it's awaiting data, processing, or was just created
  final SyslogTableCacheState state;

  /// Filters applied to the table. Subtractive, all items means no filter. Default status is everything is on.
  final SyslogFilters filters;

  SyslogTableCache({
    required this.range,
    required this.messageCount,
    required this.messages,
    required this.state,
    required this.hydratedRows,
    required this.requestedCount,
    required this.rowMapping,
    required this.messageMapping,
    required this.reservedRows,
    required this.filters,
  });

  /* String? getCell(int rowIndex, int columnIndex) {
    return messages.elementAtOrNull(rowIndex)?.message;
  } */

  SyslogTableCache copyWith({
    DateTimeRange? range,
    int? messageCount,
    Map<int, SyslogMessage>? messages,
    List<int>? hydrated,
    int? requestedCount,
    SyslogFilters? filters,
    required SyslogTableCacheState state,
  }) {
    return SyslogTableCache(
      range: range ?? this.range,
      messageCount: messageCount ?? this.messageCount,
      messages: messages ?? this.messages,
      hydratedRows: hydrated ?? hydratedRows,
      requestedCount: requestedCount ?? this.requestedCount,
      filters: filters ?? this.filters,
      state: state,
      rowMapping: rowMapping,
      messageMapping: messageMapping,
      reservedRows: reservedRows,
    );
  }

  factory SyslogTableCache.empty(DateTimeRange range, SyslogFilters filters) {
    return SyslogTableCache(range: range,
      messageCount: 0,
      messages: {},
      rowMapping: {},
      messageMapping: {},
      hydratedRows: [],
      filters: filters,
      reservedRows: Queue<int>.from([]) ,
      state: SyslogTableCacheState.created,
      requestedCount: 0
    );
  }

  SyslogMessage? getMessageAt(int rowIndex) {
    final int? rowId = rowMapping[rowIndex];

    if (rowId == null) return null;

    return  messages[rowId];
  }

  int getNextRowIndex() {
    return rowMapping.length;
  }

  int consumeNextRowIndex() {
    return reservedRows.removeFirst();
  }

  int reserveRows(int reserveCount) {
    final int offset = getNextRowIndex();
    
    for(int i = 0 ; i < reserveCount; ++i) {
      addMapping(offset + i, -1);
    }
    reservedRows.addAll(List.generate(reserveCount, (index) => offset + index));

    return offset;
  }

  void addMapping(int rowIndex, int messageId) {
    rowMapping[rowIndex] = messageId;
    messageMapping[messageId] = rowIndex;
  }


  void applyFilter(dynamic filter, bool? state) {
    filters.applySetFilter(filter, state);
  }
}