import 'package:network_analytics/models/syslog/syslog_facility.dart';
import 'package:network_analytics/models/syslog/syslog_severity.dart';

class SyslogMessage {
  int id;
  SyslogFacility facility;
  SyslogSeverity severity;
  String source;
  DateTime recievedAt;
  DateTime reportedTime;
  String syslogTag;
  String processId; // Saving as string to adhere to aiosyslogd
  String message;

  SyslogMessage({
    required this.id,
    required this.facility,
    required this.severity,
    required this.source,
    required this.recievedAt,
    required this.reportedTime,
    required this.syslogTag,
    required this.processId,
    required this.message,
  });

  factory SyslogMessage.fromJson(dynamic json) {
    return SyslogMessage(
      id: json[0],
      facility: SyslogFacility.fromInt(json[1])!,
      severity: SyslogSeverity.fromInt(json[2])!,
      source: json[3],
      recievedAt: DateTime.tryParse(json[5])!,
      reportedTime: DateTime.tryParse(json[6])!,
      syslogTag: json[7],
      processId: json[8],
      message: json[9]
    );
  }
}