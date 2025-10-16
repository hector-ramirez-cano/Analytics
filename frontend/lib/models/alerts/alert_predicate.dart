import 'package:network_analytics/models/alerts/alert_predicate_operation.dart';

class AlertPredicate {
  final dynamic left;
  final dynamic right;
  final AlertPredicateOperation op;
  
  const AlertPredicate({
    required this.left,
    required this.right,
    required this.op,
  });

  static List<AlertPredicate> listFromJson(List<dynamic> json) {
    return json.map((item) => fromJson(item)!).toList();
  }

  static AlertPredicate? fromJson(Map<String, dynamic> json) {
    final op = AlertPredicateOperation.fromString(json["op"]);
    final left = json.containsKey("left");
    final right = json.containsKey("right");

    if (op == null || !left || !right) {
      return null;
    }

    return AlertPredicate(
      left: json["left"],
      right: json["right"],
      op: op
    );
  }

  @override
  String toString() {
    return "$left ${op.toPrettyString()} $right";
  }

  Map<String, dynamic> toMap() {
    return {
      "left": left,
      "right": right,
      "op": op.toString(),
    };
  }
}