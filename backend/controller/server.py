import asyncio
import json

from quart import Quart, send_from_directory, Response
import os

from backend.model.db import get_topology_as_json
from backend.model.fact_gathering.fact_gathering import gather_all_facts

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
    topology = await get_topology_as_json()
    topology = json.dumps(topology)
    return Response(topology, content_type="application/json")
    # return await send_from_directory(routes_dir, "test-data.json")


@app.route("/api/schema/<selected>")
async def api_get_schema(selected: str):
    return await send_from_directory(schema_dir, selected)



@app.before_serving
async def startup():
    app.add_background_task(gather_all_facts)

@app.after_serving
async def shutdown():
    ansible_runner_event.set()