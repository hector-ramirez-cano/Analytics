import re
import subprocess

from backend.model.Icmp_status import IcmpStatus
from backend.model.cache import cache

import asyncio


RTT_PATTERN = re.compile(r"rtt min/avg/max/mdev = .*/(.*)/.*/.*? ms")
LOSS_PATTERN = re.compile(r"(\d\d?\d?)% packet loss")
UNREACHABLE_PATTERN = "Destination Host Unreachable"
NAME_RESOLUTION_ERROR_PATTERN = "Temporary failure in name resolution"
TIMEOUT_ERROR_PATTERN = "Request Timed Out"
HOST_NOT_FOUND_PATTERN = "Could Not Find Host"


async def __ping_host_once(host: str):
    # TODO: Switch to raw ICMP sockets for faster throughput
    result = subprocess.run(
        ['ping', '-A', '-c', '1', host],
        capture_output=True,
        text=True
    )

    rtt = 0.0
    loss = 100.0
    status = IcmpStatus.UNREACHABLE

    if result.returncode == 0:
        rtt  = float(re.findall(RTT_PATTERN, result.stdout)[0])
        loss = float(re.findall(LOSS_PATTERN, result.stdout)[0])
        status = IcmpStatus.REACHABLE

    else:
        if UNREACHABLE_PATTERN in result.stderr:
            status = IcmpStatus.UNREACHABLE

        elif TIMEOUT_ERROR_PATTERN in result.stderr:
            status = IcmpStatus.TIMEOUT

        elif NAME_RESOLUTION_ERROR_PATTERN in result.stderr:
            status = IcmpStatus.NAME_RESOLUTION_ERROR

        elif HOST_NOT_FOUND_PATTERN in result.stderr:
            status = IcmpStatus.HOST_NOT_FOUND


    return result.returncode, host, status, rtt, loss


async def __ping_devices(hosts) -> tuple[dict, dict]:
    """
    Pings devices via ICMP ECHO requests, and gathers avg_rtt and packet loss count

    return metrics_ status
    """
    tasks = [__ping_host_once(host) for host in hosts]
    results = await asyncio.gather(*tasks)

    metrics = {}
    status = {}
    for (rc, host, icmp_status, rtt, loss) in results:
        metrics[host] = {
            "icmp_status" : icmp_status,
            "icmp_rtt": rtt,
            "icmp_loss_percent": loss
        }

        status[host] = {
            "icmp_status": icmp_status.name
        }

    return metrics, status


async def gather_facts():
    """
        Calls for the execution of ICMP Echo tests for devices found on cache that match
         with "icmp" in data_sources.
    """

    targets = cache.icmp_inventory
    results = await __ping_devices(targets)

    return results
