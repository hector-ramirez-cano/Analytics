import asyncio
from quart import Quart, send_from_directory
import os

from backend.model.ansible_fact_gathering import query_facts_from_inventory

static_dir = os.path.join(os.getcwd(), "../frontend/static")
routes_dir = os.path.join(os.getcwd(), "../frontend")
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
    return await send_from_directory(routes_dir, "test-data.json")

@app.route("/favicon.ico")
async def get_favicon():
    return await send_from_directory(routes_dir, "favicon.ico")


@app.after_request
async def disable_cache(response):
    if app.debug:
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response



@app.before_serving
async def startup():
    app.add_background_task(query_facts_from_inventory)

@app.after_serving
async def shutdown():
    ansible_runner_event.set()