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
from backend.model.fact_gathering.syslog.syslog_filters import SyslogFilters


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


def __get_log_stream(filters: SyslogFilters) -> Generator[Tuple[Any, ...], None, None]:
    months = generate_months(filters.start_time, filters.end_time)

    conn = sqlite3.connect(":memory:", timeout=10)

    databases = []

    try:
        for month in months:
            db_path = f'syslog_{month}.sqlite3'
            alias = f'db_{month}'

            if not os.path.exists(db_path):
                continue

            conn.execute(f"ATTACH DATABASE '{db_path}' AS {alias}")

            databases.append(alias)

        query, params = filters.get_sql_query(target= "se.*", databases=databases)

        yield from conn.execute(
            query,
            params
        )

        conn.close()

    except Exception as e:
        print("[ERROR][SYSLOG][DB]SQL ERROR=", e)
    finally:
        conn.close()


def __handle_log_stream_set_filters(signal : dict) -> Tuple[Generator[Tuple[Any, ...], None, None], SyslogFilters]:
    filters = SyslogFilters.from_json (signal)
    return __get_log_stream(filters), filters


def __handle_log_stream_request_data(generator: Generator[Tuple[Any, ...], None, None], signal: dict, data_queue: janus.SyncQueue):
    if generator is None:
        data_queue.put_nowait(json.dumps({
            "type": "error",
            "msg": "[ERROR][SYSLOG][WS]syslog date stream data requested before a filter is set!"
        }))
        print("[ERROR][SYSLOG][WS]syslog date stream data requested before a filter is set!")

    # moar data is requested
    count = signal["count"]
    for log in islice(generator, count):
        data_queue.put_nowait(json.dumps(log))


def __handle_log_stream_request_size(signal: dict, data_queue: janus.SyncQueue):
    try:
        filters = SyslogFilters.from_json(signal)
        count = get_row_count(filters)
        data_queue.put_nowait(json.dumps({"type": "request-size", "count": count}))
    except Exception as e:
        data_queue.put_nowait(json.dumps({"type": "error", "msg": str(e)}))


def get_log_stream(data_queue: janus.SyncQueue, signal_queue: janus.SyncQueue[dict], finished: threading.Event):
    filters : SyslogFilters
    generator: Generator[Tuple[Any, ...], None, None] = None

    while not finished.is_set():
        # Block the thread until a signal is rxd
        signal = signal_queue.get()

        # noinspection PyBroadException
        try:
            print(f"[DEBUG][SYSLOG] RXd message with type={signal["type"]}")
            match signal["type"]:
                case "set-filters":
                    generator, filters  = __handle_log_stream_set_filters(signal)

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


def get_row_count(filters : SyslogFilters) -> int:
    months = generate_months(filters.start_time, filters.end_time)

    conn = sqlite3.connect(":memory:", timeout=10)

    databases = []

    try:
        for month in months:
            db_path = f'syslog_{month}.sqlite3'
            alias = f'db_{month}'

            if not os.path.exists(db_path):
                continue

            conn.execute(f"ATTACH DATABASE '{db_path}' AS {alias}")

            databases.append(alias)

        query, params = filters.get_sql_query(target="count(1) AS count", databases=databases)

        cursor = conn.execute(
            query,
            params
        )
        count = cursor.fetchone()[0]

        # Cleanup
        conn.close()

        return count
    except Exception as e:
        print(e)
        raise e
    finally:
        conn.close()