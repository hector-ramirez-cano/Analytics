import json
import asyncio
import threading
import janus

from enum import Enum

from typing import List

from model.db.operations.dashboard_operations import get_dashboards_as_dict
from model.db.health_check import check_connections
from model.db.operations.influx_operations import InfluxFilter, get_metric_data
from model.db.fetch_topology import get_topology_as_dict, get_topology_view_as_dict
from model.cache import Cache
from model.facts.fact_gathering_backend import FactGatheringBackend
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
            "msg": "[BACKEND]malformed metric filters array"
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
        msg = {"type": "error", "msg": "[BACKEND]Influx DB query encountered and exception="+str(e)}
        await data_out_queue.async_q.put(json.dumps(msg))


async def query_facts(data_out_queue: janus.Queue, inner_data : dict, label: str):
    try:
        device_ids = inner_data.get("device-ids")
        facts = inner_data.get("facts")

        # Failsafe, if only one is provided
        if isinstance(facts, str):
            facts = [facts]

        if not isinstance(facts, (list, tuple)):
            msg = {
                "type": "error",
                "msg": "[BACKEND]Query facts was called with neither a string, or an array as facts"
            }

        # Failsafe, if a group is provided instead of a device
        if isinstance(device_ids, int) and Cache().get_group(device_ids) is not None:
            device_ids = Cache().get_devices_in_group(device_ids)
            device_ids = [device.device_id for device in device_ids]

        # Failsafe, if only one is provided
        if isinstance(device_ids, int):
            device_ids = [device_ids]


        if device_ids is None or facts is None or not isinstance(device_ids, list|tuple|set):
            await data_out_queue.async_q.put("{}")
            return


        results = []
        for device_id in device_ids:
            device = Cache().get_item(device_id)
            metrics_cache = {}

            result = {}
            result["management-hostname"] = device.management_hostname
            result["device-id"] = device.device_id

            if not device is None:
                metrics_cache = FactGatheringBackend().metrics_cache.get(device.management_hostname, {})

            if metrics_cache is None:
                metrics_cache = {}

            for fact in facts:
                value = metrics_cache.get(fact, None)
                if issubclass(type(value), Enum):
                    result[fact] = str(value)
                else:
                    result[fact] = value

            results.append(result)

        result = {
            "type": "facts",
            "msg": {
                "data": results,
                label : facts,
            }
        }

        await data_out_queue.async_q.put(json.dumps(result))

    except Exception as e:
        msg = {
            "type": "error",
            "msg": "[BACKEND]Query facts encountered an error="+str(e)
        }
        await data_out_queue.async_q.put(msg)



async def check_backend_ws(data_out_queue : janus.Queue):
    """Returns a check_connection as json into the data_out_queue

    Args:
        data_out_queue (janus.Queue): Queue instance to which the check will be posted
    """
    msg = {"type": "health-rt", "msg": check_connections()}
    await data_out_queue.async_q.put(json.dumps(msg))

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

async def device_health_rt(data_out_queue: janus.Queue, _data: dict):
    msg = {
        "type": "link",
        "msg": FactGatheringBackend.to_dict(FactGatheringBackend().status_cache)
    }
    await data_out_queue.async_q.put(json.dumps(msg))


async def get_topology(data_out_queue: janus.Queue):
    topology = get_topology_as_dict()
    msg = {
        "type": "topology",
        "msg": topology
    }
    await data_out_queue.async_q.put(json.dumps(msg))

async def get_topology_view(data_out_queue: janus.Queue):
    view = get_topology_view_as_dict()
    msg = {}
    if isinstance(view, list):
        msg = {
            "type": "topology-view",
            "msg": {
                "type": "get",
                "msg": view
            }
        }
    elif isinstance(view, str):
        msg = {
            "type": "error",
            "msg": f"[BACKEND]{view}"
        }
    else:
        msg = {
            "type": "error",
            "msg": f"[BACKEND]Encountered error, topology view db consult returned value='{str(view)}'"
        }

    await data_out_queue.async_q.put(json.dumps(msg))



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
                "facility": msg["Facility"],
                "priority": msg["Priority"],
                "from-host": msg["FromHost"],
                "received-at": msg["ReceivedAt"].timestamp(),
                "syslog-tag": msg["SysLogTag"],
                "pid": int(msg["ProcessID"]),
                "device-reported-time": msg["DeviceReportedTime"].timestamp(),
                "msg": msg["Message"]
            }

            packet = { "type": "syslog-rt", "msg" : packet }
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
