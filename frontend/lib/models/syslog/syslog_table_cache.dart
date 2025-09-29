
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';

enum SyslogTableCacheState {
  created, 
  updating,
  hydrated,
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

  final Queue<int> reservedRows;

  final int requestedCount;

  /// Holds the state
  final SyslogTableCacheState state;

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
    required SyslogTableCacheState state,
  }) {
    return SyslogTableCache(
      range: range ?? this.range,
      messageCount: messageCount ?? this.messageCount,
      messages: messages ?? this.messages,
      hydratedRows: hydrated ?? hydratedRows,
      requestedCount: requestedCount ?? this.requestedCount,
      state: state,
      rowMapping: rowMapping,
      messageMapping: messageMapping,
      reservedRows: reservedRows,
    );
  }

  factory SyslogTableCache.empty(DateTimeRange range) {
    return SyslogTableCache(range: range, messageCount: 0, messages: {}, rowMapping: {}, messageMapping: {}, hydratedRows: [], reservedRows: Queue<int>.from([]) , state: SyslogTableCacheState.created, requestedCount: 0);
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
}