
import 'package:network_analytics/models/alert_severity.dart';

class AlertEvent {

  final int           alertId;
  final DateTime      alertTime;
  final bool          requiresAck;
  final AlertSeverity severity;
  final String        message;
  final int           targetId;
  final bool          acked;

  const AlertEvent({
    required this.alertId,
    required this.alertTime,
    required this.requiresAck,
    required this.severity,
    required this.message,
    required this.targetId,
    required this.acked,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      alertId: json["alert_id"],
      alertTime: DateTime.fromMillisecondsSinceEpoch((json["alert_time"]*1000).toInt(), isUtc: true),
      requiresAck: json["requires_ack"],
      severity: AlertSeverity.fromString(json['severity']),
      message: json["message"],
      targetId: json["target_id"],
      acked: json["acked"]
    );
  }
}