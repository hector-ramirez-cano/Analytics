import asyncio
import datetime
import json
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
                f"SELECT * FROM {alias}.SystemEvents WHERE ReceivedAt BETWEEN ? AND ? LIMIT -1 OFFSET ? ",
                (start_time, end_time, offset)
            )

            conn.execute(f"DETACH DATABASE {alias}")
    except Exception as e:
        print("[ERROR][SYSLOG][DB]SQL ERROR=", e)
    finally:
        conn.close()


def __handle_log_stream_set_range(signal : dict) -> Generator[Tuple[Any, ...], None, None]:
    start = datetime.datetime.fromtimestamp(float(signal["start"]))
    end = datetime.datetime.fromtimestamp(float(signal["end"]))
    offset = signal.get("offset", 0)
    return __get_log_stream(start, end, offset)



def __handle_log_stream_request_data(generator: Generator[Tuple[Any, ...], None, None], signal: dict, data_queue: janus.SyncQueue):
    if generator is None:
        data_queue.put_nowait(json.dumps({
            "type": "error",
            "msg": "[ERROR][SYSLOG][WS]syslog date stream data requested before a date range is set!"
        }))
        print("[ERROR][SYSLOG][WS]syslog date stream data requested before a date range is set!")

    # moar data is requested
    count = signal["count"]
    for log in islice(generator, count):
        data_queue.put_nowait(json.dumps(log))


def __handle_log_stream_request_size(signal: dict, data_queue: janus.SyncQueue):
    print("Request Size")
    try:
        start = datetime.datetime.fromtimestamp(float(signal["start"]))
        end = datetime.datetime.fromtimestamp(float(signal["end"]))
        count = get_row_count(start, end)
        data_queue.put_nowait(json.dumps({"type": "request-size", "count": count}))
    except Exception as e:
        data_queue.put_nowait(json.dumps({"type": "error", "msg": str(e)}))


def get_log_stream(data_queue: janus.SyncQueue, signal_queue: janus.SyncQueue[dict], finished: threading.Event):
    start_date: datetime.datetime
    end_date: datetime.datetime
    offset = 0
    generator: Generator[Tuple[Any, ...], None, None] = None

    while not finished.is_set():
        # Block the thread until a signal is rxd
        signal = signal_queue.get()

        # noinspection PyBroadException
        try:
            match signal["type"]:
                case "set-range":
                    generator  = __handle_log_stream_set_range(signal)

                case "request-data":
                    __handle_log_stream_request_data(generator, signal, data_queue)

                case "request-size":
                    __handle_log_stream_request_size(signal, data_queue)

                case _:
                    data_queue.put_nowait(json.dumps({
                        "type": "error",
                        "msg": f"[ERROR][SYSLOG][WS]Malformed websocket request = '% s' ignoring..."%str(signal)
                    }))
                    print("[ERROR][SYSLOG][WS]Malformed websocket request = '", signal, "' ignoring...")

        except Exception as e:
            data_queue.put_nowait(json.dumps({"type": "error", "msg": "BACKEND ERROR: " + str(e)}))



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