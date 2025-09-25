import asyncio
import datetime
import os
import threading
from itertools import islice
from typing import Tuple, Any, Generator

import sqlite3

import janus

from backend.model.cache import cache
from backend.model.db.update_devices import update_topology_cache


def get_topology_as_json():
    """
    Acquires topology from database, and converts it into json
    """
    [devices, links, groups] = cache.topology

    update_topology_cache()

    return {
        "devices": [devices[device_id].to_dict() for device_id in devices],
        "links": links,
        "groups": groups
    }


def generate_months(start_time: datetime.datetime, end_time: datetime.datetime) -> list[str]:
    """
    Generates a list of strings representing each YYYYMM between the two dates
    :param start_time
    :param end_time
    :returns list[str]
    """
    months: list[str] = []
    current = datetime.datetime(start_time.year, start_time.month, 1)

    while current <= end_time:
        months.append(current.strftime('%Y%m'))
        # Move to the first day of the next month
        if current.month == 12:
            current = datetime.datetime(current.year + 1, 1, 1)
        else:
            current = datetime.datetime(current.year, current.month + 1, 1)

    return months

def __get_log_stream(start_time: datetime.datetime, end_time: datetime.datetime, offset) -> Generator[Tuple[Any, ...], None, None]:
    months = generate_months(start_time, end_time)
    query_hub_path = "/tmp/syslog_query_hub.sqlite3"
    if not os.path.exists(query_hub_path):
        open(query_hub_path, "a").close()  # Create empty file

    conn = sqlite3.connect(query_hub_path, timeout=10)

    try:
        for month in months:
            db_path = f'syslog_{month}.sqlite3'
            alias = f'db_{month}'

            if not os.path.exists(db_path):
                continue

            conn.execute(f"ATTACH DATABASE '{db_path}' AS {alias}")

            yield from conn.execute(
                f"SELECT * FROM {alias}.SystemEvents WHERE ReceivedAt BETWEEN ? AND ? OFFSET = ?",
                (start_time, end_time, offset)
            )

            conn.execute(f"DETACH DATABASE {alias}")
    except Exception as e:
        print(e)
    finally:
        conn.close()


def get_log_stream(data_queue: janus.SyncQueue, signal_queue: janus.SyncQueue, finished: threading.Event):
    start_date: datetime.datetime
    end_date: datetime.datetime
    offset = 0
    generator: Generator[Tuple[Any, ...], None, None] = None

    while not finished.is_set():
        # Block the thread until a signal is rxd
        signal = signal_queue.get()

        match signal["type"]:
            case "set-date":
                # date set, reset the generator to yield values in the new range
                start_date = datetime.datetime.strptime(signal["start-date"], "%Y-%m-%d %H:%M:%S.%f")
                end_date   = datetime.datetime.strptime(signal["end-date"]  , "%Y-%m-%d %H:%M:%S.%f")
                offset     = signal["offset"]
                generator  = __get_log_stream(start_date, end_date, offset)

            case "request":
                if generator is None:
                    raise "syslog date stream data requested before a date range is set!"

                # moar data is requested
                count = signal["count"]
                for log in islice(generator, count):
                    data_queue.put_nowait(log)


def get_row_count(start_time : datetime.datetime, end_time: datetime.datetime) -> int:
    months = generate_months(start_time, end_time)
    query_hub_path = "/tmp/syslog_query_hub.sqlite3"
    if not os.path.exists(query_hub_path):
        open(query_hub_path, "a").close()  # Create empty file

    conn = sqlite3.connect(query_hub_path, timeout=10)
    count = 0

    try:
        for month in months:
            db_path = f'syslog_{month}.sqlite3'
            alias = f'db_{month}'

            if not os.path.exists(db_path):
                continue

            conn.execute(f"ATTACH DATABASE '{db_path}' AS {alias}")
            cursor = conn.execute(
                f"SELECT count(1) FROM {alias}.SystemEvents WHERE ReceivedAt BETWEEN ? AND ?",
                (start_time, end_time)
            )
            count = count + cursor.fetchone()[0]

            conn.execute(f"DETACH DATABASE {alias}")

        return count
    except Exception as e:
        print(e)
        raise e
    finally:
        conn.close()