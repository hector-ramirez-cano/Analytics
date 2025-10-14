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
}