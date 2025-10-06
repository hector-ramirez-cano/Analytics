import 'package:flutter/material.dart';
import 'package:network_analytics/models/syslog/syslog_filters.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';


class SyslogTablePage {
  static const int pageSize = 30;

  /// Count of recorded messages in the timeframe, given first before any other message
  /// Helps the caller know how many rows to expect before streaming begins
  final int messageCount;

  /// Actual mapping of messages, using the ID column on the SQLite DB, given as first parameter of the `SELECT * FROM SystemEvents;`
  final Map<int, SyslogMessage> messages;

  /// Filters applied to the table. Subtractive, all items means no filter. Default status is everything is on.
  final SyslogFilters filters;

  SyslogTablePage({
    required this.messageCount,
    required this.messages,
    required this.filters,
  });

  /* String? getCell(int rowIndex, int columnIndex) {
    return messages.elementAtOrNull(rowIndex)?.message;
  } */

  /// Returns the [pageCount] depending on the [messageCount] and [pageSize]
  int get pageCount => (messageCount / pageSize).ceil();

  /// Returns the page a [row] is found in, depending on the [pageSize]
  /// Note: Pages start counting from 1
  /// 
  /// eg.
  /// getPage(40); // pageSize=30 => 2
  /// ⌈(40 / 30)⌉ = ⌈1.333...⌉ = 2
  int getPage(int row) => (row / pageSize).ceil();

  SyslogTablePage copyWith({
    DateTimeRange? range,
    int? messageCount,
    Map<int, SyslogMessage>? messages,
    List<int>? hydrated,
    int? requestedCount,
    SyslogFilters? filters,
  }) {
    return SyslogTablePage(
      messageCount: messageCount ?? this.messageCount,
      messages: messages ?? this.messages,
      filters: filters ?? this.filters,
    );
  }

  factory SyslogTablePage.empty(SyslogFilters filters) {
    return SyslogTablePage(
      messageCount: 0,
      messages: {},
      filters: filters,
    );
  }


  void applyFilter(dynamic filter, bool? state) {
    filters.applySetFilter(filter, state);
  }
}