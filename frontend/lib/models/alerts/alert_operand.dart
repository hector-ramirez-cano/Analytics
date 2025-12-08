
import 'package:aegis/models/enums/facts_const_types.dart';

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
