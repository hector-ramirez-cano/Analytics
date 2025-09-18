import asyncio
import json

from quart import Quart, send_from_directory, Response, websocket
import os

from backend.model import db
from backend.model.db.health_check import check_connections, health_check_listeners
from backend.model.db.operations import get_topology_as_json
from backend.model.fact_gathering.syslog.syslog_backend import SyslogBackend

static_dir = os.path.join(os.getcwd(), "../frontend/static")
routes_dir = os.path.join(os.getcwd(), "../frontend")
schema_dir = os.path.join(os.getcwd(), "../backend/controller/schema")
print(os.getcwd())

ansible_runner_event = asyncio.Event()
app = Quart(__name__, static_folder=static_dir)

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

    except asyncio.CancelledError as e:
        raise

    finally:
        health_check_listeners.remove(queue)

@app.websocket("/ws/syslog")
async def api_syslog_ws():
    queue = asyncio.Queue[tuple]()
    SyslogBackend.register_listener(queue)

    try:
        while True:
            msg = await queue.get()
            await websocket.send(data=str(msg))

    except asyncio.CancelledError as e:
        raise

    finally:
        SyslogBackend.remove_listener(queue)


@app.route("/api/schema/<selected>")
async def api_get_schema(selected: str):
    return await send_from_directory(schema_dir, selected)



@app.before_serving
async def startup():
    pass


@app.after_serving
async def shutdown():
    ansible_runner_event.set()