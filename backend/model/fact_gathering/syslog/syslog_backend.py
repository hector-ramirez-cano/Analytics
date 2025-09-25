import asyncio
import datetime
import logging
import threading
from typing import *

import aiosyslogd
import janus
from aiosyslogd.db import BaseDatabase, sqlite
from aiosyslogd.server import SyslogUDPServer, BATCH_TIMEOUT, BATCH_SIZE, get_db_driver

from backend.Config import Config
from backend.model import db

logger = logging.getLogger(__name__)

class SyslogBackend(SyslogUDPServer):

    _syslog_listeners : list[asyncio.Queue[dict]] = []

    @staticmethod
    async def notify_listeners(params : dict):
        for listener in SyslogBackend._syslog_listeners:
            await listener.put(params)

    @staticmethod
    def register_listener(queue: asyncio.Queue[tuple]):
        SyslogBackend._syslog_listeners.append(queue)


    @staticmethod
    def remove_listener(queue: asyncio.Queue[tuple]):
        SyslogBackend._syslog_listeners.remove(queue)


    def __init__(self, host: str, port: int, db_driver: BaseDatabase | None):
        super().__init__(host, port, db_driver)
        self.exit_flag = None

    def set_exit_flag(self, exit_flag: asyncio.Event):
        self.exit_flag = exit_flag


    async def __original_database_writer(self, batch, params) -> None:
        # noinspection PyBroadException
        try:
            if params:
                batch.append(params)
            self._message_queue.task_done()
            if len(batch) >= BATCH_SIZE:
                if self.db:
                    await self.db.write_batch(batch)
                batch.clear()
        except asyncio.TimeoutError:
            if batch and self.db:
                await self.db.write_batch(batch)
            batch.clear()

        except Exception:
            aiosyslogd.server.logger.opt(exception=True).error("Error in database writer")


    async def database_writer(self) -> None:
        """A dedicated task to write messages to the database in batches."""
        batch: List[Dict[str, Any]] = []
        while not self._shutting_down and not self.exit_flag.is_set():

            try:
                data, addr, received_at = await asyncio.wait_for(
                    self._message_queue.get(), timeout=BATCH_TIMEOUT
                )
                params = self.process_datagram(data, addr, received_at)
                await SyslogBackend.notify_listeners(params)
                await self.__original_database_writer(batch, params)

            except asyncio.CancelledError:
                break

            except asyncio.TimeoutError:
                if self.exit_flag.is_set():
                    break

        # on close
        if batch and self.db:
            await self.db.write_batch(batch)  # Final write
        aiosyslogd.server.logger.info("Database writer task finished.")


    @staticmethod
    async def syslog_server_task(stop_event : asyncio.Event):

        host = "0.0.0.0"
        port = Config.get("backend/controller/syslog/RFC5424-port", 5541)

        loop = asyncio.get_running_loop()

        print("[INFO ][SYSLOG]Creating server on binding '", host+":"+str(port), "'")
        server = await SyslogBackend.create(host=host, port=port)
        server.set_exit_flag(exit_flag=stop_event)
        try:
            transport, protocol = await loop.create_datagram_endpoint(
                protocol_factory=lambda: server,
                local_addr=(server.host, server.port),
            )
        except OSError as e:
            print("[ERROR][SYSLOG]Failed to init Syslog with the following error: "+e.strerror)
            return

        print("[INFO ][SYSLOG]Server is listening...")
        try:
            await stop_event.wait()

        except asyncio.CancelledError:
            print("[INFO ][SYSLOG]Shutting down custom server.")
            transport.close()
            await server.shutdown()


    @staticmethod
    def spawn_log_stream(data_queue: janus.SyncQueue, signal_queue: janus.SyncQueue, finished: threading.Event) -> Coroutine:
        return asyncio.to_thread(lambda: db.operations.get_log_stream(data_queue, signal_queue, finished))


    @staticmethod
    async def get_row_count(start_date : datetime.datetime, end_date: datetime.datetime) -> int:
        return await asyncio.to_thread(lambda: db.operations.get_row_count(start_date, end_date))