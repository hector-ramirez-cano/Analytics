from enum import Enum


class SyslogFacility(Enum):
    kern     = 0     # 0                Kernel messages
    user     = 1     # 1                User-level messages
    mail     = 2     # 2                Mail system
    daemon   = 3     # 3                System daemons
    auth     = 4     # 4                Security/authentication messages
    syslog   = 5     # 5                Messages generated internally by syslogd
    lpr      = 6     # 6                Line printer subsystem
    news     = 7     # 7                Network news subsystem
    uucp     = 8     # 8                UUCP subsystem
    cron     = 9     # 9                Cron subsystem
    authpriv = 10    # 10               Security and authentication messages
    ftp      = 11    # 11               FTP daemon
    ntp      = 12    # 12               NTP subsystem
    security = 13    # 13               Log audit
    console  = 14    # 14               Log alert
    solaris  = 15    # 15               cron Scheduling daemon
    local0   = 16    # 16–23 – local7   Locally used facilities
    local1   = 17    # 16–23 – local7   Locally used facilities
    local2   = 18    # 16–23 – local7   Locally used facilities
    local3   = 19    # 16–23 – local7   Locally used facilities
    local4   = 20    # 16–23 – local7   Locally used facilities
    local5   = 21    # 16–23 – local7   Locally used facilities
    local6   = 22    # 16–23 – local7   Locally used facilities
    local7   = 23    # 16–23 – local7   Locally used facilities


    @staticmethod
    def values() -> list["SyslogFacility"]:
        return [name.value for name in SyslogFacility]


    @staticmethod
    def from_json(json: dict) -> list["SyslogFacility"]:
        return [SyslogFacility[facility] for facility in json["facility"]]


    def __str__(self) -> str:
        return self.name