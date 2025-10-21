import asyncio
import threading
import os
import json

import janus
from quart import Quart, send_from_directory, Response, websocket, request
from controller import get_operations, post_operations
from controller.sentinel import Sentinel
from model.alerts.alert_backend import AlertBackend
from model.db.health_check import check_connections, health_check_listeners
from model.syslog.syslog_backend import SyslogBackend


static_dir = os.path.join(os.getcwd(), "../frontend/static")
routes_dir = os.path.join(os.getcwd(), "../frontend")
schema_dir = os.path.join(os.getcwd(), "../backend/controller/schema")
print(os.getcwd())

ansible_runner_event = asyncio.Event()
app = Quart(__name__, static_folder=static_dir)

#  ________                  __                      __              __
# /        |                /  |                    /  |            /  |
# $$$$$$$$/  _______    ____$$ |  ______    ______  $$/  _______   _$$ |_    _______
# $$ |__    /       \  /    $$ | /      \  /      \ /  |/       \ / $$   |  /       |
# $$    |   $$$$$$$  |/$$$$$$$ |/$$$$$$  |/$$$$$$  |$$ |$$$$$$$  |$$$$$$/  /$$$$$$$/
# $$$$$/    $$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |$$ |  $$ |  $$ | __$$      \
# $$ |_____ $$ |  $$ |$$ \__$$ |$$ |__$$ |$$ \__$$ |$$ |$$ |  $$ |  $$ |/  |$$$$$$  |
# $$       |$$ |  $$ |$$    $$ |$$    $$/ $$    $$/ $$ |$$ |  $$ |  $$  $$//     $$/
# $$$$$$$$/ $$/   $$/  $$$$$$$/ $$$$$$$/   $$$$$$/  $$/ $$/   $$/    $$$$/ $$$$$$$/
#                               $$ |
#                               $$ |
#                               $$/
@app.route("/heartbeat")
async def __heartbeat():
    print("[DEBUG]Heartbeat!")
    return "Bip bop"

@app.route("/api/topology", methods=['GET'])
async def __api_get_topology():
    return get_operations.api_get_topology()

@app.route("/api/rules", methods=['GET'])
async def __api_get_rules():
    return get_operations.api_get_rules()


@app.route("/api/configure", methods=['POST'])
async def __api_configure():
    data = await request.get_data()

    try:
        result, msg = await post_operations.api_configure(data)

        if not result:
            raise Exception(msg)

        return Response(status=200)

    except Exception as e:
        return Response(status=400, response=str(e))

#  __       __            __                                      __                    __
# /  |  _  /  |          /  |                                    /  |                  /  |
# $$ | / \ $$ |  ______  $$ |____    _______   ______    _______ $$ |   __   ______   _$$ |_    _______
# $$ |/$  \$$ | /      \ $$      \  /       | /      \  /       |$$ |  /  | /      \ / $$   |  /       |
# $$ /$$$  $$ |/$$$$$$  |$$$$$$$  |/$$$$$$$/ /$$$$$$  |/$$$$$$$/ $$ |_/$$/ /$$$$$$  |$$$$$$/  /$$$$$$$/
# $$ $$/$$ $$ |$$    $$ |$$ |  $$ |$$      \ $$ |  $$ |$$ |      $$   $$<  $$    $$ |  $$ | __$$      \
# $$$$/  $$$$ |$$$$$$$$/ $$ |__$$ | $$$$$$  |$$ \__$$ |$$ \_____ $$$$$$  \ $$$$$$$$/   $$ |/  |$$$$$$  |
# $$$/    $$$ |$$       |$$    $$/ /     $$/ $$    $$/ $$       |$$ | $$  |$$       |  $$  $$//     $$/
# $$/      $$/  $$$$$$$/ $$$$$$$/  $$$$$$$/   $$$$$$/   $$$$$$$/ $$/   $$/  $$$$$$$/    $$$$/ $$$$$$$/
# TODO: Move to ws_operations


@app.websocket("/ws/router")
async def __api_ws_router():

    health_check_subscription_queue = asyncio.Queue()
    alerts_subscription_queue = asyncio.Queue()
    syslog_subscription_queue = asyncio.Queue()

    data_out_queue = janus.Queue()
    syslog_signal_queue = janus.Queue()
    alert_signal_queue = janus.Queue()
    finished_event = threading.Event()

    syslog_thread = SyslogBackend.spawn_log_stream(
        data_out_queue.sync_q,
        syslog_signal_queue.sync_q,
        finished_event
    )

    alert_thread = AlertBackend.spawn_log_stream(
        data_out_queue.sync_q,
        alert_signal_queue.sync_q,
        finished_event
    )

    # Subscribe to event notifiers
    health_check_listeners.append(health_check_subscription_queue)
    SyslogBackend.register_listener(syslog_subscription_queue)
    AlertBackend.register_listener(alerts_subscription_queue)

    async def rx():
        while True:
            data = await websocket.receive_json()
            inner_data = data["msg"]

            match data["type"]:
                case "syslog":
                    await __api_syslog_ws(syslog_signal_queue, inner_data)

                case "alerts":
                    await __api_alerts_ws(alert_signal_queue, inner_data)

                case "health":
                    await __api_check_backend_ws(data_out_queue)


    async def tx():
        while True:
            data = await data_out_queue.async_q.get()
            await websocket.send(data)

    producer = asyncio.create_task(tx())
    consumer = asyncio.create_task(rx())
    syslog_rt = asyncio.create_task(__api_syslog_rt_ws(data_out_queue, syslog_subscription_queue, finished_event))
    alerts_rt = asyncio.create_task(__api_alerts_rt_ws(data_out_queue, alerts_subscription_queue , finished_event))
    

    try:
        await asyncio.gather(producer, consumer, syslog_thread, alert_thread, alerts_rt, syslog_rt)
    except asyncio.CancelledError as e:
        print("[ERROR][WS]Websocket encountered error=", e)

    finally:
        # remove subscriptions
        # TODO: Change this to stop interacting directly with the queue
        health_check_listeners.remove(health_check_subscription_queue)
        SyslogBackend.remove_listener(syslog_subscription_queue)
        AlertBackend.remove_listener(alerts_subscription_queue)

        # task queues to close via sentinels
        await syslog_signal_queue.async_q.put(Sentinel())
        await alert_signal_queue.async_q.put(Sentinel())

        # close rx and tx
        producer.cancel()
        consumer.cancel()

        # close queues and socket
        finished_event.set()
        await syslog_signal_queue.aclose()
        await alert_signal_queue.aclose()
        await data_out_queue.aclose()
        await websocket.close(-1)

async def __api_check_backend_ws(data_out_queue : janus.Queue):
    await data_out_queue.async_q.put(str(check_connections))

async def __api_syslog_ws(signal_queue: janus.Queue, data: dict):
    # if 'list', handle the multiple commands
    if isinstance(data, list):
        for obj in data:
            await signal_queue.async_q.put(obj)
    elif isinstance(data, dict):
        # if 'dict', it's only one, so only execute once
        await signal_queue.async_q.put(data)

async def __api_alerts_ws(signal_queue: janus.Queue, data: dict):
    # if 'list', handle the multiple commands
    if isinstance(data, list):
        for obj in data:
            await signal_queue.async_q.put(obj)
    elif isinstance(data, dict):
        # if 'dict', it's only one, so only execute once
        await signal_queue.async_q.put(data)

async def __api_syslog_rt_ws(data_out_queue: janus.Queue, queue: asyncio.Queue, finished: threading.Event):
    # TODO: Change this to conform to schema, and whatever-this-style-is-called
    while not finished.is_set():
        try:
            msg = await queue.get()

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

async def __api_alerts_rt_ws(data_out_queue: janus.Queue, queue: asyncio.Queue, finished: threading.Event):
    while not finished.is_set():
        try:
            msg = await queue.get()

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


@app.websocket("/ws/topology")
async def __api_topology_ws():
    # TODO: Handle topology via websocket
    pass


@app.route("/api/schema/<selected>")
async def __api_get_schema(selected: str):
    return await send_from_directory(schema_dir, selected)



@app.before_serving
async def __startup():
    pass


@app.after_serving
async def __shutdown():
    ansible_runner_event.set()
