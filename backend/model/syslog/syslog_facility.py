from enum import Enum


class SyslogFacility(Enum):
    KERN     = 0     # 0                Kernel messages
    USER     = 1     # 1                User-level messages
    MAIL     = 2     # 2                Mail system
    DAEMON   = 3     # 3                System daemons
    AUTH     = 4     # 4                Security/authentication messages
    SYSLOG   = 5     # 5                Messages generated internally by syslogd
    LPR      = 6     # 6                Line printer subsystem
    NEWS     = 7     # 7                Network news subsystem
    UUCP     = 8     # 8                UUCP subsystem
    CRON     = 9     # 9                Cron subsystem
    AUTHPRIV = 10    # 10               Security and authentication messages
    FTP      = 11    # 11               FTP daemon
    NTP      = 12    # 12               NTP subsystem
    SECURITY = 13    # 13               Log audit
    CONSOLE  = 14    # 14               Log alert
    SOLARIS  = 15    # 15               cron Scheduling daemon
    LOCAL0   = 16    # 16–23 – local7   Locally used facilities
    LOCAL1   = 17    # 16–23 – local7   Locally used facilities
    LOCAL2   = 18    # 16–23 – local7   Locally used facilities
    LOCAL3   = 19    # 16–23 – local7   Locally used facilities
    LOCAL4   = 20    # 16–23 – local7   Locally used facilities
    LOCAL5   = 21    # 16–23 – local7   Locally used facilities
    LOCAL6   = 22    # 16–23 – local7   Locally used facilities
    LOCAL7   = 23    # 16–23 – local7   Locally used facilities


    @staticmethod
    def values() -> list["SyslogFacility"]:
        return [name.value for name in SyslogFacility]


    @staticmethod
    def from_json(json: dict) -> list["SyslogFacility"]:
        return [SyslogFacility[facility.upper()] for facility in json]


    def __str__(self) -> str:
        return self.name