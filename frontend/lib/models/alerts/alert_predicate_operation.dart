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

  @override
  String toString() {
    return toSnakeCase(super.toString().replaceAll(_nameRegex, ""));
  }
}