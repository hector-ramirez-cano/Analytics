import 'package:network_analytics/models/enums/facts_const_types.dart';

final RegExp _nameRegex = RegExp("AlertPredicateOperation.");

String toSnakeCase(String input) {
  final pattern = RegExp(r'(?<=[a-z0-9])([A-Z])');
  final snake = input
      .replaceAllMapped(pattern, (match) => '_${match.group(0)}')
      .replaceAll(RegExp(r'\s+'), '_')
      .toLowerCase();
  return snake;
}


enum AlertPredicateOperation {
  moreThan,
  moreThanEqual,
  lessThan,
  lessThanEqual,
  equal,
  notEqual,
  contains;


  static AlertPredicateOperation? fromString(String value) {
    switch (value.toLowerCase()) {
      case "more_than":
        return moreThan;

      case "more_than_equal":
        return moreThanEqual;

      case "less_than":
        return lessThan;

      case "less_than_equal":
        return lessThanEqual;

      case "equal":
        return equal;

      case "not_equal":
        return notEqual;

      case "contains":
        return contains;
    }

    return null;
  }

  String toPrettyString() {
    switch (this) {
      
      case AlertPredicateOperation.moreThan:
        return " > ";
        
      case AlertPredicateOperation.moreThanEqual:
        return " ≥ ";

      case AlertPredicateOperation.lessThan:
        return " < ";

      case AlertPredicateOperation.lessThanEqual:
        return " ≤ ";
        
      case AlertPredicateOperation.equal:
        return " = ";

      case AlertPredicateOperation.notEqual:
        return " ≠ ";

      case AlertPredicateOperation.contains:
        return "∈";
    }
  }

  /// Returns whether the operator is performed between numbers, holding sense in arithmetics
  bool isArithmetic() {
    switch (this) {
      // Only these cases are considered arithmetic
      case moreThan:
      case moreThanEqual:
      case lessThan:
      case lessThanEqual:
      case equal:
      case notEqual:
        return true;

      // there's no point in executing with numbers
      case contains:
        return false;
    }
  }

  /// Returns whether the operator is performed with a boolean, holding sense in boolean logic
  bool isBoolean() {
    switch (this) {
      // Only these two cases are considered boolean operations
      case equal:
      case notEqual:
        return true;

      // There's no point executing them with boolean
      // Despite being technically valid, in the sense that:
      /// ``` >>> True > 2 # Yields False```
      /// It doesn't cause an exception, as True is treated as 1, and False 0
      /// However, it's better to disallow this case, and force comparison between booleans
      case moreThan:
      case moreThanEqual:
      case lessThan:
      case lessThanEqual:
      case contains:
        return false;
    }
  }

  /// Returns whether the operator is performed with strings, holding sense for strings
  bool isString() {
    switch (this) {
      case equal:
      case notEqual:
      case contains:
        return true;
      
      case moreThan:
      case moreThanEqual:
      case lessThan:
      case lessThanEqual:
        return false;
    }
  }

  /// Returns whether the operator is performed with a null value, holding sense for a null value
  bool isNull() {
    switch(this) {
      case AlertPredicateOperation.equal:
      case AlertPredicateOperation.notEqual:
      case AlertPredicateOperation.contains:
        return true;
      
      case AlertPredicateOperation.moreThan:
      case AlertPredicateOperation.moreThanEqual:
      case AlertPredicateOperation.lessThan:
      case AlertPredicateOperation.lessThanEqual:
        return false;
      
    }
  }

  /// Returns whether the operator can performed if at least one side is of the given [type]
  bool isValidFor(FactsDataType type) {
    switch(type) {
      
      case FactsDataType.string:
        return isString();

      case FactsDataType.number:
        return isArithmetic();
        
      case FactsDataType.boolean:
        return isBoolean();

      case FactsDataType.nullable:
        return isNull();
    }
  }

  @override
  String toString() {
    return toSnakeCase(super.toString().replaceAll(_nameRegex, ""));
  }
}