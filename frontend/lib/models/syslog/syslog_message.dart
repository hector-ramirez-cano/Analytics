import 'package:aegis/models/syslog/syslog_facility.dart';
import 'package:aegis/models/syslog/syslog_severity.dart';

class SyslogMessage {
  int id;
  SyslogFacility facility;
  SyslogSeverity severity;
  String source;
  DateTime recievedAt;
  String processId; // Saving as string to adhere to aiosyslogd
  String message;

  SyslogMessage({
    required this.id,
    required this.facility,
    required this.severity,
    required this.source,
    required this.recievedAt,
    required this.processId,
    required this.message,
  });

  factory SyslogMessage.fromJsonArr(List<dynamic> json) {
    return SyslogMessage(
      id: json[0],
      facility: SyslogFacility.fromInt(json[1])!,
      severity: SyslogSeverity.fromInt(json[2])!,
      source: json[3],
      recievedAt: DateTime.tryParse(json[5])!,
      processId: json[6],
      message: json[7]
    );
  }

  factory SyslogMessage.fromJson(Map<String, dynamic> json) {
    return SyslogMessage(
      id: json['id'],
      facility: SyslogFacility.fromString(json['facility'])!,
      severity: SyslogSeverity.fromString(json['severity'])!,
      source: json['source'],
      recievedAt: DateTime.tryParse(json['received-at'])!,
      processId: json['process-id'],
      message: json['message'],
    );
  }

  @override
  String toString() {
    return message;
  }
}