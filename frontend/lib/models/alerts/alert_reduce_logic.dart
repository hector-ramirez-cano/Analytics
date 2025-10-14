enum AlertReduceLogic {
  all,
  any,
  
  unknown;

  static AlertReduceLogic fromString(String value) {
    switch (value.toLowerCase()) {
      case "all":
        return all;

      case "any":
        return any;
    }

    return unknown;
  }
}