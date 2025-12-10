
import 'package:aegis/models/alerts/alert_severity.dart';

class AlertEvent {

  final int           id;
  final DateTime      alertTime;
  final DateTime?     ackTime;
  final bool          requiresAck;
  final AlertSeverity severity;
  final String        message;
  final String?       ackActor;
  final int           targetId;
  final bool          acked;
  final String        value;

  const AlertEvent({
    required this.id,
    required this.alertTime,
    required this.ackTime,
    required this.requiresAck,
    required this.severity,
    required this.message,
    required this.ackActor,
    required this.targetId,
    required this.acked,
    required this.value,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    //"{"alert-id": 50, "alert-time": 1760046734.721805, "ack-time": null, "requires_ack": true, "severity": "warning", "message": "'ICMP_RTT > 600ms' triggered for device='Xochimilco-lan'!", "target-id": 1, "acked": false}"
  
    final ackTime = json["ack-time"] == null ? null : DateTime.fromMillisecondsSinceEpoch((json["ack-time"]*1000).toInt(), isUtc: true);

    return AlertEvent(
      id: json["alert-id"],
      alertTime:  DateTime.fromMillisecondsSinceEpoch((json["alert-time"]*1000).toInt(), isUtc: true),
      ackTime: ackTime,
      requiresAck: json["requires-ack"],
      severity: AlertSeverity.fromString(json["severity"]),
      message: json["message"],
      ackActor: json["ack-actor"] ?? "Sin confirmar",
      targetId: json["target-id"],
      acked: json["acked"] != null,
      value: json["value"]?? ""
    );
  }

  factory AlertEvent.fromJsonArr(List<dynamic> json) {

    final ackTime = json[2] == null ? null : DateTime.fromMillisecondsSinceEpoch((json[2]*1000).toInt(), isUtc: true);

    return AlertEvent(
      id: json[0],
      alertTime: DateTime.fromMillisecondsSinceEpoch((json[1]*1000).toInt(), isUtc: true),
      ackTime: ackTime, // json[2]
      requiresAck: json[3],
      severity: AlertSeverity.fromString(json[4]),
      message: json[5],
      ackActor: json[6],
      acked: json[6] != null,
      targetId: json[7],
      value: json[8],
    );
  }
}