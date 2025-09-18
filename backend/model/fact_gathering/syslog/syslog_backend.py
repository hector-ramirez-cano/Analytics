import asyncio
import logging
from typing import *

import aiosyslogd
from aiosyslogd.db import BaseDatabase
from aiosyslogd.server import SyslogUDPServer, BATCH_TIMEOUT, BATCH_SIZE

from backend.Config import Config

logger = logging.getLogger(__name__)

class SyslogBackend(SyslogUDPServer):

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
                print(params) # TODO: Somehow pass this to the frontend and analyze it for patterns
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


