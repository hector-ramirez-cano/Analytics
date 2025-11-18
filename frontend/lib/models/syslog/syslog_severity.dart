/// Syslog severity levels as specified in the RFC 5424 https://www.rfc-editor.org/rfc/rfc5424
enum SyslogSeverity {
  emerg,
  alert,
  crit,
  err,
  warning,
  notice,
  info,
  debug;

  /// Returns the corresponding SyslogSeverity corresponding with the numeric value, or null if out of range
  static SyslogSeverity? fromInt(int value) {
    if (value >= 0 && value <= 7) {
      return SyslogSeverity.values[value];
    }

    return null;
  }

  /// Returns the corresponding SyslogSeverity corresponding with the string, or null if out of range
  static SyslogSeverity? fromString(String name) {
    try {
      return SyslogSeverity.values.byName(name);
    }
    catch (_) {
      return null;
    }
  }

  @override 
  String toString() {
    return super.toString().substring("SyslogSeverity.".length);
  }
}