enum FactsDataType {
  string,
  number,
  boolean,
  nullable,;

  static FactsDataType? fromString(String value) {
    switch (value) {
      case "string":
        return string;
      case "number":
        return number;
      case "boolean":
        return boolean;
      case "nullable":
        return nullable;
    }
    return null;
  }

  static FactsDataType? fromValue(dynamic value) {
    if (value is String) { return string  ; }
    if (value is num   ) { return number  ; }
    if (value is bool  ) { return boolean ; }
    if (value == null  ) { return nullable; }
    return null;
  }
}