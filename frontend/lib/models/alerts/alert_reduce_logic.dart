final RegExp _nameRegex = RegExp("AlertReduceLogic.");
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

  @override
  String toString() {
    return super.toString().replaceAll(_nameRegex, "");
  }
}