import 'package:aegis/models/alerts/alert_operand.dart';
import 'package:aegis/models/alerts/alert_operand_modifier.dart';
import 'package:aegis/models/alerts/alert_predicate_operation.dart';
import 'package:aegis/models/enums/facts_const_types.dart';


class AlertPredicate {
  const AlertPredicate({
    required this.left,
    required this.leftModifier,
    required this.right,
    required this.rightModifier,
    required this.op,
  });

  factory AlertPredicate.empty() {
    return AlertPredicate(
      left: AlertRuleOperand.empty(),
      right: AlertRuleOperand.empty(),
      op: AlertPredicateOperation.contains,
      leftModifier: OperandModifierNone(),
      rightModifier: OperandModifierNone(),
    );
  }

  final OperandModifier leftModifier;
  final AlertRuleOperand left;
  final AlertPredicateOperation? op;
  final AlertRuleOperand right;
  final OperandModifier rightModifier;

  @override
  String toString() {
    return "$left ${op?.toPrettyString()} $right";
  }

  static List<AlertPredicate> listFromJson(List<dynamic> json) {
    return json.map((item) => fromJson(item)!).toList();
  }

  static Map<String, dynamic> extractModifier(Map<String, dynamic> src, String key) {
    final value = src[key];

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is String) {
      return {value: null};
    }

    return {};
  }

  static AlertPredicate? fromJson(Map<String, dynamic> json) {
    final op = AlertPredicateOperation.fromString(json["op"]);
    final left = json.containsKey("left");
    final right = json.containsKey("right");

    if (op == null || !left || !right) {
      return null;
    }

    return AlertPredicate(
      left : AlertRuleOperand.fromValue(json["left"]),
      leftModifier: OperandModifier.fromJson(extractModifier(json, "left-modifier")),
      right: AlertRuleOperand.fromValue(json["right"]),
      rightModifier: OperandModifier.fromJson(extractModifier(json, "right-modifier")),
      op: op
    );
  }

  AlertPredicate setConstType(FactsDataType type) {
    if (left.isConst ) { return copyWith(left : left.copyWith (dataType: type)); }
    if (right.isConst) { return copyWith(right: right.copyWith(dataType: type)); }
    return copyWith();
  }

  AlertPredicate setLeftConst(bool value) {
    // left becomes value
    // if right is const && value, reset
    // if right isn't const, keep it
    final AlertRuleOperand newLeft;
    final AlertRuleOperand newRight;
    if (value) {

      newLeft = AlertRuleOperand(value: null, isConst: true, dataType: FactsDataType.nullable, isInit: false);
      if (right.isConst) {
      newRight = AlertRuleOperand.empty();
      } else {
        newRight = right;
      }

    } else {
      // we're just setting not const, we can just straight up copy it
      newLeft = left.copyWith(isConst: false, dataType: FactsDataType.string);
      newRight = right;
    }
    return copyWith(left: newLeft, right: newRight);
  }

  AlertPredicate setRightConst(bool value) {
    // Right becomes value
    // if Left is const && value, reset
    // if Left isn't const, keep it
    final AlertRuleOperand newRight;
    final AlertRuleOperand newLeft;
    if (value) {
      
      newRight = AlertRuleOperand(value: null, isConst: true, dataType: FactsDataType.nullable, isInit: false);
      if (left.isConst) {
      newLeft = AlertRuleOperand.empty();
      } else {
        newLeft = left;
      }

    } else {
      // we're just setting not const, we can just straight up copy it
      newRight = right.copyWith(isConst: false, dataType: FactsDataType.string);
      newLeft = left;
    }
    return copyWith(right: newRight, left: newLeft);
  }

  AlertPredicate setLeftForced(bool value) => copyWith(left: left.copyWith(isForced: value));

  AlertPredicate setRightForced(bool value) => copyWith(right: right.copyWith(isForced: value));

  AlertPredicate setOperation(AlertPredicateOperation? operation) => copyWith(op: operation);

  AlertPredicate setLeftValue(dynamic value) => copyWith(left: left.setValue(value));

  AlertPredicate setRightValue(dynamic value) => copyWith(right: right.setValue(value));

  AlertPredicate copyWith({AlertRuleOperand? left, AlertRuleOperand? right, AlertPredicateOperation? op, OperandModifier? leftModifier, OperandModifier? rightModifier}) 
    => AlertPredicate(
      left: left ?? this.left,
      right: right ?? this.right,
      op: op ?? this.op,
      leftModifier: leftModifier ?? this.leftModifier,
      rightModifier: rightModifier ?? this.rightModifier
    );

  AlertPredicate forcedCopy({required AlertRuleOperand left, required AlertRuleOperand right, required AlertPredicateOperation? op, required OperandModifier leftModifier, required OperandModifier rightModifier}) 
    => AlertPredicate(left: left, right: right, op: op, leftModifier: leftModifier, rightModifier: rightModifier);

  AlertPredicate setValue (dynamic value, bool isLeft) 
    => isLeft ? setLeftValue (value) : setRightValue (value);

  AlertPredicate copyWithValue(dynamic value, bool isLeft)
    => isLeft ? copyWith(left: left.copyWith(value: value)) : copyWith(right: right.copyWith(value: value));

  AlertPredicate setForced(bool    value, bool isLeft) => isLeft ? setLeftForced(value) : setRightForced(value);

  AlertPredicate setConst (bool    value, bool isLeft) => isLeft ? setLeftConst (value) : setRightConst (value);

  bool isConst(bool isLeft) => isLeft ? left.isConst : right.isConst;
  bool isLeftConst() => left.isConst;
  bool isRightConst() => right.isConst;
  bool hasConst() => left.isConst || right.isConst;

  AlertRuleOperand? get constValue => left.isConst ? left : right.isConst ? right : null;

  bool get isValid => left.isValid && right.isValid && op != null;


  Map<String, dynamic> toMap() {
    return {
      "left": left.toMap(),
      "right": right.toMap(),
      "op": op.toString(),
      "left-modifier": leftModifier.toMap(),
      "right-modifier": rightModifier.toMap()
    };
  }
}