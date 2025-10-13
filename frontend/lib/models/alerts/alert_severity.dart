enum AlertSeverity {
  emergency,
  alert,
  critical,
  error,
  warning,
  notice,
  info,
  debug,

  unknown
  ;

  factory AlertSeverity.fromString(String value) {
    switch (value) {
      
      case 'emergency':
        return AlertSeverity.emergency;

      case 'alert':
        return AlertSeverity.alert;

      case 'critical':
        return AlertSeverity.critical;

      case 'error':
        return AlertSeverity.error;

      case 'warning':
        return AlertSeverity.warning;

      case 'notice':
        return AlertSeverity.notice;

      case 'info':
        return AlertSeverity.info;

      case 'debug':
        return AlertSeverity.debug;

      default:
        return AlertSeverity.unknown;
    }
  }

  @override
  String toString() {
    return super.toString().substring("AlertSeverity.".length);
  }
}