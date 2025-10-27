import asyncio
import threading
import os
import json

import janus
from quart import Quart, send_from_directory, Response, websocket, request
from controller import get_operations, post_operations, ws_operations
from controller.sentinel import Sentinel
from model.alerts.alert_backend import AlertBackend
from model.syslog.syslog_backend import SyslogBackend
from model.db.health_check import health_check_listeners



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

    async def rx(finished_event: asyncio.Event):
        while not finished_event.is_set():
            try:
                data = await websocket.receive_json()
            except json.JSONDecodeError as e:
                msg = {"type": "error","msg": "[BACKEND]malformed json message, e="+str(e)}
                await data_out_queue.async_q.put(json.dumps(msg))
                continue

            except Exception as e:
                msg = {"type": "error","msg": "[BACKEND]Exception found at message receiver, e="+str(e)}
                await data_out_queue.async_q.put(json.dumps(msg))
                continue
            inner_data = data.get("msg", {})

            print(f"\033[0;37;46m{json.dumps(data)} \033[0m")

            match data["type"]:
                case "syslog":
                    await ws_operations.syslog_ws(syslog_signal_queue, inner_data)

                case "alerts":
                    await ws_operations.alerts_ws(alert_signal_queue, inner_data)

                case "health":
                    await ws_operations.check_backend_ws(data_out_queue)

                case "dashboards":
                    await ws_operations.get_dashboards(data_out_queue)

                case "metrics":
                    await ws_operations.query_metrics(data_out_queue, inner_data)

                case "facts":
                    await ws_operations.query_facts(data_out_queue, inner_data)

                case "metadata":
                    # TODO: Change this, so metadata comes from database, facts come from local cache ? (is it useful?)
                    await ws_operations.query_facts(data_out_queue, inner_data)


                case _:
                    msg = {
                        "type": "error",
                        "msg": "[BACKEND]unmatched route type='"+data["type"] + "', ignoring..."
                    }
                    await websocket.send(json.dumps(msg))

    async def tx():
        while True:
            data = await data_out_queue.async_q.get()

            if data == Sentinel():
                break

            await websocket.send(data)

    producer = asyncio.create_task(tx())
    consumer = asyncio.create_task(rx(finished_event))
    syslog_rt = asyncio.create_task(ws_operations.syslog_rt(data_out_queue, syslog_subscription_queue, finished_event))
    alerts_rt = asyncio.create_task(ws_operations.alerts_rt(data_out_queue, alerts_subscription_queue , finished_event))


    try:
        await asyncio.gather(producer, consumer, syslog_thread, alert_thread, alerts_rt, syslog_rt)
    except Exception as e:
        print("[ERROR][WS]Websocket encountered error=", e)
        msg = {"type": "error", "msg": "[BACKEND]websocket router encountered a fatal error="+str(e)}
        await websocket.send(json.dumps(msg))

    finally:
        # remove subscriptions

        health_check_listeners.remove(health_check_subscription_queue) # TODO: Change this to stop interacting directly with the queue
        SyslogBackend.remove_listener(syslog_subscription_queue)
        AlertBackend.remove_listener(alerts_subscription_queue)

        # task queues to close via sentinels
        sentinel = Sentinel()
        await syslog_signal_queue.async_q.put(sentinel)
        await alert_signal_queue.async_q.put(sentinel)
        await data_out_queue.async_q.put(sentinel)

        # close rx and tx
        producer.cancel()
        consumer.cancel()

        # close queues and socket
        finished_event.set()
        await syslog_signal_queue.aclose()
        await alert_signal_queue.aclose()
        await data_out_queue.aclose()
        await websocket.close(-1)


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
