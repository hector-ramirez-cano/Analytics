import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_serverity.dart';

class SyslogMessage {
  String source;
  DateTime recievedAt;
  SyslogFacility facility;
  SyslogServerity severity;
  DateTime reportedTime;
  int processId;
  String message;

  SyslogMessage({
    required this.facility,
    required this.severity,
    required this.source,
    required this.recievedAt,
    required this.reportedTime,
    required this.processId,
    required this.message,
  });
}