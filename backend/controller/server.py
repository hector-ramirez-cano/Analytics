import asyncio
import datetime
import json
import threading
from warnings import deprecated

import janus
from quart import Quart, send_from_directory, Response, websocket, request
import os


from backend.model.db.health_check import check_connections, health_check_listeners
from backend.model.db.operations import get_topology_as_json
from backend.model.fact_gathering.syslog.syslog_backend import SyslogBackend

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
async def heartbeat():
    print("[DEBUG]Heartbeat!")
    return "Bip bop"

@app.route("/api/topology")
async def api_get_topology():
    topology = get_topology_as_json()
    topology = json.dumps(topology)
    return Response(topology, content_type="application/json")
    # return await send_from_directory(routes_dir, "test-data.json")

@app.route("/api/syslog/message_count")
async def api_syslog_message_count():
    start = request.args.get("start", default="")
    end = request.args.get("end", default="")

    try:
        start = datetime.datetime.fromtimestamp(float(start))
        end   = datetime.datetime.fromtimestamp(float(end))
    except ValueError as e:
        return Response(str(e), status=400)

    except TypeError as e:
        return Response(str(e), status=400)

    count = await SyslogBackend.get_row_count(start, end)

    response = json.dumps({"count": count})

    return Response(response, content_type="application/json")


#  __       __            __                                      __                    __
# /  |  _  /  |          /  |                                    /  |                  /  |
# $$ | / \ $$ |  ______  $$ |____    _______   ______    _______ $$ |   __   ______   _$$ |_    _______
# $$ |/$  \$$ | /      \ $$      \  /       | /      \  /       |$$ |  /  | /      \ / $$   |  /       |
# $$ /$$$  $$ |/$$$$$$  |$$$$$$$  |/$$$$$$$/ /$$$$$$  |/$$$$$$$/ $$ |_/$$/ /$$$$$$  |$$$$$$/  /$$$$$$$/
# $$ $$/$$ $$ |$$    $$ |$$ |  $$ |$$      \ $$ |  $$ |$$ |      $$   $$<  $$    $$ |  $$ | __$$      \
# $$$$/  $$$$ |$$$$$$$$/ $$ |__$$ | $$$$$$  |$$ \__$$ |$$ \_____ $$$$$$  \ $$$$$$$$/   $$ |/  |$$$$$$  |
# $$$/    $$$ |$$       |$$    $$/ /     $$/ $$    $$/ $$       |$$ | $$  |$$       |  $$  $$//     $$/
# $$/      $$/  $$$$$$$/ $$$$$$$/  $$$$$$$/   $$$$$$/   $$$$$$$/ $$/   $$/  $$$$$$$/    $$$$/ $$$$$$$/

@app.route("/ws/health")
async def api_check_backend():
    return  check_connections()


@app.websocket("/ws/health")
async def api_check_backend_ws():
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
async def api_syslog_ws():
    data_queue = janus.Queue()
    signal_queue = janus.Queue()
    finished_event = threading.Event()

    syslog_thread = SyslogBackend.spawn_log_stream(data_queue.sync_q, signal_queue.sync_q, finished_event)

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
        await asyncio.gather(producer, consumer, syslog_thread)
    except asyncio.CancelledError as _:
        finished_event.set()
        await signal_queue.aclose()
        await data_queue.aclose()
        await websocket.close(-1)


@app.websocket("/ws/syslog/realtime")
async def api_syslog_rt_ws():
    queue = asyncio.Queue[dict]()
    SyslogBackend.register_listener(queue)

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

    except asyncio.CancelledError as _:
        raise

    finally:
        SyslogBackend.remove_listener(queue)


@app.websocket("/ws/topology")
async def api_topology_ws():
    pass


@app.route("/api/schema/<selected>")
async def api_get_schema(selected: str):
    return await send_from_directory(schema_dir, selected)



@app.before_serving
async def startup():
    pass


@app.after_serving
async def shutdown():
    ansible_runner_event.set()
