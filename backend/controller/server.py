import asyncio
import json

from quart import Quart, send_from_directory, Response
import os

from backend.model.ansible_fact_gathering import query_facts_from_inventory
from backend.model.db import get_topology_as_json

static_dir = os.path.join(os.getcwd(), "../frontend/static")
routes_dir = os.path.join(os.getcwd(), "../frontend")
schema_dir = os.path.join(os.getcwd(), "../backend/controller/schema")
print(os.getcwd())

ansible_runner_event = asyncio.Event()
app = Quart(__name__, static_folder=static_dir)

@app.route("/")
async def home():
    response = await send_from_directory(routes_dir, "test.html")
    if app.debug:
        response.headers.pop('ETag', None)
        response.headers.pop('Last-Modified', None)
        response.headers['Cache-Control'] = 'no-store'
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"

    return response

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
    app.add_background_task(query_facts_from_inventory)

@app.after_serving
async def shutdown():
    ansible_runner_event.set()