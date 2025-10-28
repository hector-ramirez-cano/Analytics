import 'package:network_analytics/models/alerts/alert_predicate_operation.dart';
import 'package:network_analytics/models/enums/facts_const_types.dart';


class AlertRuleOperand {
  factory AlertRuleOperand.empty() {
    return AlertRuleOperand(value: null, isConst: false, dataType: FactsDataType.string, isInit: false);
  }

  factory AlertRuleOperand.fromString(String value) {
    bool isConst = !(value.toString().contains(constChar));

    FactsDataType? dataType =  FactsDataType.fromValue(value);

    dynamic localValue = unknownCast(value);

    if (!isConst && localValue is String) {
      localValue = value.replaceAll(constChar, "");
    }

    if (dataType == null) {
      return AlertRuleOperand(value: null, isConst: false, dataType: FactsDataType.nullable, isInit: false);
    }
    return AlertRuleOperand(value: localValue, isConst: isConst, dataType: dataType, isInit: true);
  }

  factory AlertRuleOperand.fromValue(dynamic value) {
    bool isConst = !(value.toString().contains(constChar));

    FactsDataType? dataType =  FactsDataType.fromValue(value);

    if (!isConst && value is String) {
      value = value.replaceAll(constChar, "");
    }

    if (dataType == null) {
      return AlertRuleOperand(value: null, isConst: false, dataType: FactsDataType.nullable, isInit: false);
    }
    return AlertRuleOperand(value: value, isConst: isConst, dataType: dataType, isInit: true);
  }

  AlertRuleOperand setValue(dynamic value) {
    if (!isConst) { return copyWith(value: value); }

    switch (dataType) {
      
      case FactsDataType.string:
        return copyWith(value: value.toString());
        
      case FactsDataType.number:
        return copyWith(value: double.tryParse(value));
        
      case FactsDataType.boolean:
        bool? boolean = value == "true" ? true : value == "false" ? false : null;
        return copyWith(value: boolean);

      case FactsDataType.nullable:
        return copyWith(value: null);
    }
  }

  static final String constChar = "&";

  final FactsDataType dataType;
  final bool isConst;
  final bool isForced;
  final bool isInit;
  final dynamic value;

  @override
  String toString() {
    if (!isInit) return "";

    if (dataType == FactsDataType.string) {
      if (!isConst) {
        return "$constChar$value";
      }
      return '"$value"';
    }

    return value.toString();
  }

  AlertRuleOperand ({
    required this.value,
    required this.isConst,
    required this.dataType,
    this.isInit = false,
    this.isForced = false,
  });

  bool get isNullableValid => value == null   && dataType == FactsDataType.nullable;
  bool get isNumberValid   => value is num    && dataType == FactsDataType.number;
  bool get isStringValid   => value is String && dataType == FactsDataType.string;
  bool get isBoolValid     => value is bool   && dataType == FactsDataType.boolean;
  bool get isValueValid    => (value != null   && (isNumberValid || isStringValid || isBoolValid)) || isNullableValid;

  bool get isValid => isInit && isValueValid;

  AlertRuleOperand copyWith({dynamic value, bool? isConst, bool? isInit, bool? isForced, FactsDataType? dataType}) {
    return AlertRuleOperand(
      value: value ?? this.value,
      isConst: isConst ?? this.isConst,
      isForced: isForced ?? this.isForced,
      dataType: dataType ?? this.dataType,
      isInit:  true,
    );
  }

  dynamic toMap() {
    if (!isConst && dataType == FactsDataType.string) {
      return "$constChar$value";
    }
    return value;
  }

  dynamic cast(String text) {

    if (!isConst) { return "&$text"; }

    switch (dataType) {
      
      case FactsDataType.string:
        return text;

      case FactsDataType.number:
        return double.parse(text);

      // these types should never call to cast
      case FactsDataType.boolean:
      case FactsDataType.nullable:
        throw Exception("Unreachable code reached!");
    }
  }

  static dynamic unknownCast(dynamic value) {
    if (value is! String) return value;

    if (value == "false" || value == "true") { return value == "true"; }
    if (value == "null") { return null; }

    final asNumber = double.tryParse(value);
    if (asNumber != null) { return asNumber; }
    
    return value;
  }
}

class AlertPredicate {
  const AlertPredicate({
    required this.left,
    required this.right,
    required this.op,
  });

  factory AlertPredicate.empty() {
    return AlertPredicate(left: AlertRuleOperand.empty(), right: AlertRuleOperand.empty(), op: AlertPredicateOperation.contains);
  }

  final AlertRuleOperand left;
  final AlertPredicateOperation? op;
  final AlertRuleOperand right;

  @override
  String toString() {
    return "$left ${op?.toPrettyString()} $right";
  }

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
      left : AlertRuleOperand.fromValue(json["left"]),
      right: AlertRuleOperand.fromValue(json["right"]),
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

  AlertPredicate copyWith({AlertRuleOperand? left, AlertRuleOperand? right, AlertPredicateOperation? op}) 
    => AlertPredicate(left: left ?? this.left, right: right ?? this.right, op: op ?? this.op);

  AlertPredicate forcedCopy({required AlertRuleOperand left, required AlertRuleOperand right, required AlertPredicateOperation? op}) 
    => AlertPredicate(left: left, right: right, op: op);

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
    };
  }
}