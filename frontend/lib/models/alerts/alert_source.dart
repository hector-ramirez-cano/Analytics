final RegExp _nameRegex = RegExp("AlertSource.");

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

  @override
  String toString() {
    return super.toString().replaceAll(_nameRegex, "");
  }
}