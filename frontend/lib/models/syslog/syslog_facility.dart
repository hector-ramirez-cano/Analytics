/// Syslog Facilities as specified in the syslog(3) command for linux: https://linux.die.net/man/3/syslog
enum SyslogFacility {
  kern,          // 0 	Kernel messages
  user,          // 1 	User-level messages
  mail,          // 2 	Mail system
  daemon,        // 3 	System daemons
  auth,          // 4 	Security/authentication messages
  syslog,        // 5 	Messages generated internally by syslogd
  lpr,           // 6 	Line printer subsystem
  news,          // 7 	Network news subsystem
  uucp,          // 8 	UUCP subsystem
  cron,          // 9 	Cron subsystem
  authpriv,      // 10 	Security and authentication messages
  ftp,           // 11 	FTP daemon
  ntp,           // 12 	NTP subsystem
  security,      // 13 	Log audit
  console,       // 14 	Log alert
  solaris,       // 15  cron 	Scheduling daemon
  local0,        // 16–23 – local7 	Locally used facilities
  local1,        // 16–23 – local7 	Locally used facilities
  local2,        // 16–23 – local7 	Locally used facilities
  local3,        // 16–23 – local7 	Locally used facilities
  local4,        // 16–23 – local7 	Locally used facilities
  local5,        // 16–23 – local7 	Locally used facilities
  local6,        // 16–23 – local7 	Locally used facilities
  local7;        // 16–23 – local7 	Locally used facilities

  /// Returns the corresponding [SyslogFacility] enum from a numeric code, or null if out of range
  static SyslogFacility? fromInt(int code) {
    if (code <= 23 && code >= 0) {
      return SyslogFacility.values[code];
    }
    return null;
  }

  // TODO: Unit tests
  /// Returns the corresponding [SyslogFacility] enum from a string or null if out of range
  static SyslogFacility? fromString(String name) {
    try {
      return SyslogFacility.values.byName(name);
    } catch (_) {
      return null;
    }
  }

  @override 
  String toString() {
    return super.toString().substring("SyslogFacility.".length);
  }


}