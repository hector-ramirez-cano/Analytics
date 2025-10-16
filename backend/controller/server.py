import asyncio
import threading
import os

import janus
from quart import Quart, send_from_directory, Response, websocket, request
from controller import get_operations, post_operations
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

@app.route("/ws/health")
async def __api_check_backend():
    return check_connections()


@app.websocket("/ws/health")
async def __api_check_backend_ws():
    queue = asyncio.Queue()
    health_check_listeners.append(queue)

    # send first msg
    await websocket.send(data=str(check_connections()))

    try:
        while True:
            msg = await queue.get()
            await websocket.send(data=str(msg))

    except asyncio.CancelledError as _:
        raise

    finally:
        health_check_listeners.remove(queue)

@app.websocket("/ws/syslog")
async def __api_syslog_ws():
    data_queue = janus.Queue()
    signal_queue = janus.Queue()
    finished_event = threading.Event()

    syslog_thread = SyslogBackend.spawn_log_stream(
        data_queue.sync_q,
        signal_queue.sync_q,
        finished_event
    )

    async def rx():
        while True:
            data = await websocket.receive_json()
            # if 'list', handle the multiple commands
            if isinstance(data, list):
                for obj in data:
                    await signal_queue.async_q.put(obj)
            elif isinstance(data, dict):
                # if 'dict', it's only one, so only execute once
                await signal_queue.async_q.put(data)


    async def tx():
        while True:
            data = await data_queue.async_q.get()
            await websocket.send(str(data))

    producer = asyncio.create_task(tx())
    consumer = asyncio.create_task(rx())

    try:
        await asyncio.gather(producer, consumer, syslog_thread)
    except asyncio.CancelledError as _:
        finished_event.set()
        await signal_queue.aclose()
        await data_queue.aclose()
        await websocket.close(-1)

@app.websocket("/ws/alerts")
async def __api_alerts_ws():
    data_queue = janus.Queue()
    signal_queue = janus.Queue()
    finished_event = threading.Event()

    alert_thread = AlertBackend.spawn_log_stream(data_queue.sync_q, signal_queue.sync_q, finished_event)

    async def rx():
        while True:
            data = await websocket.receive_json()
            # if 'list', handle the multiple commands
            if type(data) is list:
                for obj in data:
                    await signal_queue.async_q.put(obj)
            elif type(data) is dict:
                # if 'dict', it's only one, so only execute once
                await signal_queue.async_q.put(data)


    async def tx():
        while True:
            data = await data_queue.async_q.get()
            await websocket.send(str(data))

    producer = asyncio.create_task(tx())
    consumer = asyncio.create_task(rx())

    try:
        await asyncio.gather(producer, consumer, alert_thread)
    except asyncio.CancelledError as _:
        finished_event.set()
        await signal_queue.aclose()
        await data_queue.aclose()
        await websocket.close(-1)


@app.websocket("/ws/syslog/realtime")
async def __api_syslog_rt_ws():
    queue = asyncio.Queue[dict]()
    SyslogBackend.register_listener(queue)

    # TODO: Change this to conform to schema, and whatever-this-style-is-called
    try:
        while True:
            msg = await queue.get()
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
            await websocket.send(data=str(packet))

    finally:
        SyslogBackend.remove_listener(queue)

@app.websocket("/ws/alerts/realtime")
async def __api_alerts_rt_ws():
    queue = asyncio.Queue()
    await AlertBackend.register_listener(queue)

    # send first message
    await websocket.send(data="")

    try:
        while True:
            msg = await queue.get()
            await websocket.send(data=str(msg))

    # TODO: Better error handling
    except asyncio.CancelledError as _:
        print("[ERROR][WS]Cancelled websocket connection")
        

    finally:
        await AlertBackend.remove_listener(queue)


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
