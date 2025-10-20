enum FactsDataTypes {
  string,
  number,
  boolean,
  nullable,;

  static FactsDataTypes? fromString(String value) {
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
}