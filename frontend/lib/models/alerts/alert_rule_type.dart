
enum AlertRuleType {
  simple,
  delta,
  sustained,

  unknown;

  static AlertRuleType fromString(String str) {
    switch (str.toLowerCase()) {
      case "simple":
        return AlertRuleType.simple;

      case "delta":
        return AlertRuleType.delta;

      case "sustained":
        return AlertRuleType.sustained;

      default:
        return AlertRuleType.unknown;
    }
  }

  static (AlertRuleType, int) fromJson(Map<String, dynamic> json) {
    final header = json["rule-type"];

    if (header == "simple") { return (AlertRuleType.simple, 0); }
    if (header == "delta")  { return (AlertRuleType.delta, 0);  }
    if (header is Map && header["sustained"] != null) { return (AlertRuleType.sustained, header["sustained"]["seconds"] ?? -1); }

    return (AlertRuleType.unknown, -1);
  }

  dynamic toJson(int sustainedTimerSeconds) {
    switch (this) {
      
      case AlertRuleType.simple:
        return "simple";

      case AlertRuleType.delta:
        return "delta";

      case AlertRuleType.sustained:
        return {"sustained": {
          "seconds": sustainedTimerSeconds
        }};
        
      case AlertRuleType.unknown:
        return "unknown";
    }
  }
}

