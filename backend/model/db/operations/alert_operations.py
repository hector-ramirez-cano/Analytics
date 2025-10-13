import json
import janus
import threading
from itertools import islice
from typing import Tuple, Any, Generator
from datetime import datetime

from model.db.pools import postgres_db_pool
from model.alerts.alert_filters import AlertFilters


def get_alert_stream(data_queue: janus.SyncQueue, signal_queue: janus.SyncQueue[dict], finished: threading.Event):
    filters : AlertFilters = None
    generator: Generator[Tuple[Any, ...], None, None] = None

    while not finished.is_set():
        # Block the thread until a signal is rxd
        signal = signal_queue.get()

        # noinspection PyBroadException
        try:
            print(f"[DEBUG][ALERTS] RXd message with type={signal["type"]}")
            match signal["type"]:
                case "set-filters":
                    generator, filters  = __handle_alert_stream_set_filters(signal)

                case "request-data":
                    __handle_alert_stream_request_data(generator, signal, data_queue)

                case "request-size":
                    if filters is None:
                        raise "Size requested before filters are set"

                    __handle_alert_stream_request_size(filters, data_queue)

                case _:
                    data_queue.put_nowait(json.dumps({
                        "type": "error",
                        "msg": f"[ERROR][ALERTS][WS]Malformed websocket request = '% s' ignoring..."%str(signal)
                    }))
                    print("[ERROR][ALERTS][WS]Malformed websocket request = '", signal, "' ignoring...")

        except Exception as e:
            data_queue.put_nowait(json.dumps({"type": "error", "msg": "BACKEND ERROR: " + str(e)}))



def __get_alert_stream(filters: AlertFilters) -> Generator[Tuple[Any, ...], None, None]:
    try:
        query, params = filters.get_sql_query(target="*")
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)

                for row in cur:
                    _row = [field.timestamp() if isinstance(field, datetime) else field for field in row]
                    yield _row

    except Exception as e:
        # TODO: Somehow notify the controller to regen the stream if failed
        print("[ERROR][ALERTS][DB]SQL ERROR=", e)



def __handle_alert_stream_set_filters(signal : dict) -> Tuple[Generator[Tuple[Any, ...], None, None], AlertFilters]:
    filters = AlertFilters.from_json (signal)
    return __get_alert_stream(filters), filters


def __handle_alert_stream_request_data(generator: Generator[Tuple[Any, ...], None, None], signal: dict, data_queue: janus.SyncQueue):
    if generator is None:
        data_queue.put_nowait(json.dumps({
            "type": "error",
            "msg": "[ERROR][ALERTS][WS]Alert stream data requested before a filter is set!"
        }))
        print("[ERROR][ALERTS][WS]Alert stream data requested before a filter is set!")

    # moar data is requested
    count = signal["count"]
    for log in islice(generator, count):
        data_queue.put_nowait(json.dumps(log))


def __handle_alert_stream_request_size(filters: AlertFilters, data_queue: janus.SyncQueue):
    try:
        count = get_row_count(filters)
        data_queue.put_nowait(json.dumps({"type": "request-size", "count": count}))
    except Exception as e:
        data_queue.put_nowait(json.dumps({"type": "error", "msg": str(e)}))


def get_row_count(filters : AlertFilters) -> int:
    try:
        query, params = filters.get_sql_query(target="count(1) AS count")
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)

                count = cur.fetchone()[0]

                return count
    except Exception as e:
        # TODO: Somehow notify the controller to regen the stream if failed
        print("[ERROR][ALERTS][DB]SQL ERROR=", e)