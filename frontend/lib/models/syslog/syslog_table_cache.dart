
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network_analytics/models/syslog/syslog_filters.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';

enum SyslogTableCacheState {
  createdUpdating,
  updating,
  hydrated;

  bool get isUpdating => this == updating || this == createdUpdating;
}

class SyslogTableCache {
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

  factory SyslogTableCache.empty(SyslogFilters filters) {
    return SyslogTableCache(
      messageCount: 0,
      messages: {},
      rowMapping: {},
      messageMapping: {},
      hydratedRows: [],
      filters: filters,
      reservedRows: Queue<int>.from([]) ,
      state: SyslogTableCacheState.createdUpdating,
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