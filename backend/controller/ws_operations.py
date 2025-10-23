import json
import asyncio
import threading
import janus

from model.db.operations.dashboard_operations import get_dashboards_as_dict
from model.db.health_check import check_connections
from model.db.operations.influx_operations import InfluxFilter, get_metric_data
from controller.sentinel import Sentinel

async def get_dashboards(data_out_queue: janus.Queue):
    """Puts the dashboard as json into the data_out_queue

    Args:
        data_out_queue (janus.Queue): Queue instance to which data will be posted
    """
    dashboards = {
        "type": "dashboards",
        "msg": get_dashboards_as_dict()
    }

    await data_out_queue.async_q.put(json.dumps(dashboards))


async def query_metrics(data_out_queue: janus.Queue, filters: dict):
    filters = InfluxFilter.from_json(filters)

    if filters is None:
        error = {
            "type": "error",
            "msg": "malformed metric filters array"
        }
        await data_out_queue.async_q.put(json.dumps(error))
        return

    try:
        metrics = get_metric_data(filters)

        metrics = {
            "type":"metrics",
            "metric": filters.metric,
            "msg": metrics
        }

        await data_out_queue.async_q.put(json.dumps(metrics))
    except Exception as e:
        msg = {"type": "error", "msg": "Influx DB query encountered and exception="+str(e)}
        await data_out_queue.async_q.put(json.dumps(msg))





async def check_backend_ws(data_out_queue : janus.Queue):
    """Returns a check_connection as json into the data_out_queue

    Args:
        data_out_queue (janus.Queue): Queue instance to which the check will be posted
    """
    await data_out_queue.async_q.put(str(check_connections))

async def syslog_ws(signal_queue: janus.Queue, data: dict | list):
    """Executes commands related to syslog db access for past syslog messages.
    values should be passed as a dictionary containing the command type, and parameters
    for execution in accordance to the JSON Schema for syslog db access

    Args:
        signal_queue (janus.Queue): Queue to which the data will be posted to by the syslog backend
        data (dict|list): dictionary of either a single command, or a list of commands to be executed in sequence
    """
    # if 'list', handle the multiple commands
    if isinstance(data, list):
        for obj in data:
            await signal_queue.async_q.put(obj)

    elif isinstance(data, dict):
        # if 'dict', it's only one, so only execute once
        await signal_queue.async_q.put(data)


async def alerts_ws(signal_queue: janus.Queue, data: dict):
    """Executes commands related to alerts db access for past alert.
    values should be passed as a dictionary containing the command type, and parameters
    for execution in accordance to the JSON Schema for alerts db access

    Args:
        signal_queue (janus.Queue): Queue to which the data will be posted to by the alerts backend
        data (dict|list): dictionary of either a single command, or a list of commands to be executed in sequence
    """
    # if 'list', handle the multiple commands
    if isinstance(data, list):
        for obj in data:
            await signal_queue.async_q.put(obj)

    elif isinstance(data, dict):
        # if 'dict', it's only one, so only execute once
        await signal_queue.async_q.put(data)


async def syslog_rt(data_out_queue: janus.Queue, queue_in: asyncio.Queue, finished: threading.Event):
    """Loop of syslog message retransmiter via the websocket to active listeners

    If a Sentinel() singleton is passed into queue(asyncio.Queue), the loop will stop awaiting for a new
    message, and immediately evaluate the finished threading.Event

    Args:
        data_out_queue (janus.Queue): Queue to which new messages will be posted to
        queue_in (asyncio.Queue): Input queue from the Syslog backend from which new events will be recieved
        finished (threading.Event): Event indicating the end of the program, for graceful shutdown.
    """
    # TODO: Change this to conform to style, and whatever-this-style-is-called
    while not finished.is_set():
        try:
            msg = await queue_in.get()

            if msg == Sentinel():
                break

            packet = {
                "Facility": msg["Facility"],
                "Priority": msg["Priority"],
                "FromHost": msg["FromHost"],
                "ReceivedAt": msg["ReceivedAt"].timestamp(),
                "SysLogTag": msg["SysLogTag"],
                "ProcessID": int(msg["ProcessID"]),
                "DeviceReportedTime": msg["DeviceReportedTime"].timestamp(),
                "Msg": msg["Message"]
            }

            packet = { "syslog-rt" : packet }
            await data_out_queue.async_q.put(json.dumps(packet))

        except Exception as e:
            print("[ERROR][WS]Syslog realtime errored with=", str(e))

async def alerts_rt(data_out_queue: janus.Queue, queue_in: asyncio.Queue, finished: threading.Event):
    """Loop of Alerts real-time message retransmiter via the websocket to active listeners

    If a Sentinel() singleton is passed into queue(asyncio.Queue), the loop will stop awaiting for a new
    message, and immediately exit

    Args:
        data_out_queue (janus.Queue): Queue to which new messages will be posted to
        queue_in (asyncio.Queue): Input queue from the Alerts backend from which new events will be recieved
        finished (threading.Event): Event indicating the end of the program, for graceful shutdown.
    """
    while not finished.is_set():
        try:
            msg = await queue_in.get()

            if msg == Sentinel():
                break

            msg = {
                "type": "alerts-rt",
                "msg": msg.to_dict(stringify=True)
            }

            msg = json.dumps(msg)

            await data_out_queue.async_q.put(msg)

        # TODO: Better error handling
        except Exception as e:
            print("[ERROR][WS]Alert realtime errored with=", str(e))
