import os
from asyncio import Task

import Config
from backend.controller import server

import uvloop
import asyncio
import hypercorn.config
import hypercorn.asyncio

from backend.model import db
from backend.model.alerts.alert_backend import AlertBackend
from backend.model.db.health_check import check_postgres_connection, periodic_health_check
from backend.model.db.pools import init_db_pool
from backend.model.fact_gathering.fact_gathering import FactGatheringBackend
from backend.model.fact_gathering.syslog.syslog_backend import SyslogBackend

server_task       : Task[None]
facts_task        : Task[None]
facts_writer_task : Task[None]
syslog_task       : Task[None]
db_health_task    : Task[None]

stop_event        : asyncio.Event

binding           : str

def init() -> tuple:
    global server_task, facts_task, facts_writer_task, syslog_task, db_health_task, binding
    global stop_event

    # TODO: Replace with Logger
    print("[INFO ]CWD=", os.getcwd())
    is_debug = os.environ.get("DEBUG") == "1"
    print("[DEBUG]is_debug=", is_debug)

    ### Init config ###
    config = Config.config

    ### Init database ###
    init_db_pool(check_postgres_connection)

    ### Fact Gathering ###
    FactGatheringBackend.init()

    ### Init alert subsystem ###
    # (Must come after db and factGathering init)
    AlertBackend.init()

    ### Init HTTP server ###
    port = config.get("backend/controller/api/port", 5050)

    # Hypercorn config stuff
    binding = "0.0.0.0:" + str(port)
    hypercorn_config = hypercorn.config.Config()
    hypercorn_config.bind = [binding]

    # Hypercorn webserver serve
    server_task = asyncio.create_task(hypercorn.asyncio.serve(server.app, hypercorn_config))

    # fact queue
    fact_queue = asyncio.Queue[tuple]()

    stop_event = asyncio.Event()

    # add background tasks
    facts_task = asyncio.create_task(FactGatheringBackend.gather_facts_task(stop_event, fact_queue))
    facts_writer_task = asyncio.create_task(FactGatheringBackend.update_listeners(stop_event, fact_queue))
    syslog_task = asyncio.create_task(SyslogBackend.syslog_server_task(stop_event))
    db_health_task = asyncio.create_task(periodic_health_check(stop_event))

    return server_task


async def main():
    global stop_event, binding

    init()


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