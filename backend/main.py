import os

import Config
from backend.controller import server

import uvloop
import asyncio
import hypercorn.config
import hypercorn.asyncio

from backend.model import db
from backend.model.db.health_check import check_postgres_connection, periodic_health_check
from backend.model.db.pools import init_db_pool

from backend.model.fact_gathering.fact_gathering import gather_facts_task, database_update_facts
from backend.model.fact_gathering.syslog.syslog_backend import SyslogBackend


def init():
    # TODO: Replace with Logger
    print("[INFO ]CWD=", os.getcwd())


async def main():
    init()

    config = Config.config
    init_db_pool(check_postgres_connection)
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

    # fact queue
    fact_queue = asyncio.Queue[tuple]()

    # add background tasks
    # facts_task = asyncio.create_task(gather_facts_task(stop_event, fact_queue))
    # facts_writer_task = asyncio.create_task(database_update_facts(stop_event, fact_queue))
    # syslog_task = asyncio.create_task(SyslogBackend.syslog_server_task(stop_event))
    # db_health_task = asyncio.create_task(periodic_health_check(stop_event))

    try:
        await server_task

    except OSError as e:
        print("[ERROR][HTTP ]Failed to bind to ["+binding+"] with error msg=" + e.strerror)
        stop_event.set()


    # graceful shutdown
    print("[INFO]Graceful shutdown requested, awaiting pending tasks to finish...")
    stop_event.set()
    syslog_task.cancel()

    await asyncio.gather(facts_task, facts_writer_task, syslog_task, db_health_task)

    db.pools.graceful_shutdown()


if __name__ == "__main__":
    with asyncio.Runner(loop_factory=uvloop.new_event_loop) as runner:
        runner.run(main())