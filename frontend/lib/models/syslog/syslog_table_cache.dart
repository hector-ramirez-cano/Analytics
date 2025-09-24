
import 'package:flutter/material.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';

class SyslogTableCache {
  final DateTimeRange range;
  final int messageCount;
  final List<SyslogMessage> messages;

  const SyslogTableCache({
    required this.range,
    required this.messageCount,
    required this.messages,
  });

  String? getCell(int rowIndex, int columnIndex) {
    return messages.elementAtOrNull(rowIndex)?.message;
  }
}