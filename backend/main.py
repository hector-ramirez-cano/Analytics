import os

import Config
from backend.model.db import init_db_pool
from backend.controller import server

import asyncio
import hypercorn.config
import hypercorn.asyncio

from backend.model.fact_gathering.fact_gathering import  gather_facts_task


def init():
    # TODO: Replace with Logger
    print("[INFO ]CWD=", os.getcwd())


async def main():
    init()

    config = Config.config
    init_db_pool()
    port = config.get("backend/controller/api/port", 5050)

    is_debug =os.environ.get("DEBUG") == "1"
    print("[DEBUG]is_debug=",is_debug)

    # Hypercorn config stuff
    binding : str = "0.0.0.0:"+str(port)
    hypercorn_config = hypercorn.config.Config()
    hypercorn_config.bind = [binding]

    stop_event = asyncio.Event()

    # Hypercorn webserver serve
    server_task = asyncio.create_task(hypercorn.asyncio.serve(server.app, hypercorn_config))

    # add my background tasks
    loop = asyncio.get_running_loop()
    facts_task = asyncio.create_task(gather_facts_task(stop_event))
    # syslog_task = asyncio.create_task(syslog_server_task())

    await server_task

    # graceful shutdown
    stop_event.set()
    await facts_task



if __name__ == "__main__":
    asyncio.run(main())