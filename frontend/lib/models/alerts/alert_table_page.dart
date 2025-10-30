import 'package:flutter/material.dart';
import 'package:aegis/models/alerts/alert_event.dart';
import 'package:aegis/models/alerts/alert_filters.dart';


class AlertTablePage {
  static const int pageSize = 30;

  /// Count of recorded events in the timeframe, given first before any other message
  /// Helps the caller know how many rows to expect before streaming begins
  final int messageCount;

  /// Actual mapping of events, using the ID column on the DB, given as first parameter of the `SELECT * FROM Analytics.alerts;`
  final Map<int, AlertEvent> events;

  /// Filters applied to the table. Subtractive, all items means no filter. Default status is everything is on, aka everything displays.
  final AlertFilters filters;

  AlertTablePage({
    required this.messageCount,
    required this.events,
    required this.filters,
  });

  /// Returns the [pageCount] depending on the [messageCount] and [pageSize]
  int get pageCount => (messageCount / pageSize).ceil();

  /// Returns the page a [row] is found in, depending on the [pageSize]
  /// Note: Pages start counting from 1
  /// 
  /// eg.
  /// getPage(40); // pageSize=30 => 2
  /// ⌈(40 / 30)⌉ = ⌈1.333...⌉ = 2
  int getPage(int row) => (row / pageSize).ceil();

  AlertTablePage copyWith({
    DateTimeRange? range,
    int? messageCount,
    Map<int, AlertEvent>? events,
    List<int>? hydrated,
    int? requestedCount,
    AlertFilters? filters,
  }) {
    return AlertTablePage(
      messageCount: messageCount ?? this.messageCount,
      events: events ?? this.events,
      filters: filters ?? this.filters,
    );
  }

  factory AlertTablePage.empty(AlertFilters filters) {
    return AlertTablePage(
      messageCount: 0,
      events: {},
      filters: filters,
    );
  }


  void applyFilter(dynamic filter, bool? state) {
    filters.applySetFilter(filter, state);
  }
}