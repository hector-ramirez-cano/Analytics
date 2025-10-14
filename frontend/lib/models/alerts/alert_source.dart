enum AlertSource {
  syslog,
  facts,

  unknown;

  factory AlertSource.fromString(String value) {
    switch (value) {
      case "syslog":
        return syslog;

      case "facts":
        return facts;
    }

    return unknown;
  }
}