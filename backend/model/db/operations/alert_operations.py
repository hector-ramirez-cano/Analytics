import json
import threading
from itertools import islice
from typing import Tuple, Any, Generator
from datetime import datetime
import janus

from model.db.pools import postgres_db_pool
from model.alerts.alert_filters import AlertFilters
from model.alerts.alert_event import AlertEvent


def get_alert_stream(data_queue: janus.SyncQueue, signal_queue: janus.SyncQueue[dict], finished: threading.Event):
    filters : AlertFilters = None
    generator: Generator[Tuple[Any, ...], None, None] = None

    while not finished.is_set():
        # Block the thread until a signal is rxd
        signal = signal_queue.get()

        # noinspection PyBroadException
        try:
            print(f'[DEBUG][ALERTS] RXd message with type={signal['type']}')
            match signal['type']:
                case 'set-filters':
                    generator, filters  = __handle_alert_stream_set_filters(signal)

                case 'request-data':
                    __handle_alert_stream_request_data(generator, signal, data_queue)

                case 'request-size':
                    if filters is None:
                        raise Exception('Size requested before filters are set')

                    __handle_alert_stream_request_size(filters, data_queue)

                case _:
                    data_queue.put_nowait(json.dumps({
                        'type': 'error',
                        'msg': f"[ERROR][ALERTS][WS]Malformed websocket request = '{str(signal)}' ignoring..."
                    }))
                    print('[ERROR][ALERTS][WS]Malformed websocket request = '', signal, '' ignoring...')

        except Exception as e:
            data_queue.put_nowait(json.dumps({'type': 'error', 'msg': 'BACKEND ERROR: ' + str(e)}))


def __get_alert_stream(filters: AlertFilters) -> Generator[Tuple[Any, ...], None, None]:
    try:
        query, params = filters.get_sql_query(target='*')
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)

                for row in cur:
                    _row = [field.timestamp() if isinstance(field, datetime) else field for field in row]
                    yield _row

    except Exception as e:
        # TODO: Somehow notify the controller to regen the stream if failed
        print('[ERROR][ALERTS][DB]SQL ERROR=', e)



def __handle_alert_stream_set_filters(signal : dict) -> Tuple[Generator[Tuple[Any, ...], None, None], AlertFilters]:
    filters = AlertFilters.from_json (signal)
    return __get_alert_stream(filters), filters


def __handle_alert_stream_request_data(generator: Generator[Tuple[Any, ...], None, None], signal: dict, data_queue: janus.SyncQueue):
    if generator is None:
        data_queue.put_nowait(json.dumps({
            'type': 'error',
            'msg': '[ERROR][ALERTS][WS]Alert stream data requested before a filter is set!'
        }))
        print('[ERROR][ALERTS][WS]Alert stream data requested before a filter is set!')

    # moar data is requested
    count = signal['count']
    for log in islice(generator, count):
        msg = {'type': 'alerts', 'msg': log}
        data_queue.put_nowait(json.dumps(msg))


def __handle_alert_stream_request_size(filters: AlertFilters, data_queue: janus.SyncQueue):
    try:
        count = get_row_count(filters)
        data_queue.put_nowait(json.dumps({'type':'alerts', 'msg':{'type': 'request-size', 'count': count}}))
    except Exception as e:
        data_queue.put_nowait(json.dumps({'type': 'error', 'msg': str(e)}))


def get_row_count(filters : AlertFilters) -> int:
    try:
        query, params = filters.get_sql_query(target='count(1) AS count')
        with postgres_db_pool().connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)

                count = cur.fetchone()[0]

                return count
    except Exception as e:
        # TODO: Somehow notify the controller to regen the stream if failed
        print('[ERROR][ALERTS][DB]SQL ERROR=', e)


def update_alert_config() -> list[tuple]:
    with postgres_db_pool().connection() as conn, conn.cursor() as cur:
        cur.execute(
            """
                SELECT * FROM Analytics.alert_rules
            """
        )

        rules = []

        for row in cur.fetchall():
            rule_id = row[0]
            name = row[1]
            requires_ack = row[2]
            definition = row[3]
            rules.append((rule_id, name, requires_ack, definition))

        return rules


def insert_alert(alert: AlertEvent) -> bool:
    """
    Updates the database with a new alert event, as received by the worker thread.
    :param alert event
    """
    try:
        with postgres_db_pool().connection() as conn, conn.cursor() as cur:
            cur.execute(
                """
                    INSERT INTO Analytics.alerts(alert_time, requires_ack, severity, message, target_id, value) 
                    VALUES (%s, %s , %s , %s, %s, %s)
                    RETURNING alert_id;
                """,
                (alert.alert_time, alert.requires_ack, alert.severity.value, alert.message, alert.target_id, alert.value)
            )

            alert.alert_id = cur.fetchone()[0]

        return True

    except Exception as e:
        print(f"[ERROR][DB]Failed to insert Alert with error='{str(e)}'")
        return False

def get_rules_as_list() -> list[dict]:
    rules = update_alert_config()

    arr = []

    for rule in rules:
        arr.append({
            "rule-id": rule[0],
            "name": rule[1],
            "requires-ack": rule[2],
            "definition": rule[3]
        })

    return arr
