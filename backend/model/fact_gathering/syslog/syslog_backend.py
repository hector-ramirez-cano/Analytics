import asyncio
from asyncio import AbstractEventLoop
from typing import *

import aiosyslogd
from aiosyslogd.server import SyslogUDPServer, BATCH_TIMEOUT, BATCH_SIZE

from backend.Config import Config

class SyslogBackend(SyslogUDPServer):


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
        while not self._shutting_down:

            try:
                data, addr, received_at = await asyncio.wait_for(
                    self._message_queue.get(), timeout=BATCH_TIMEOUT
                )
                params = self.process_datagram(data, addr, received_at)
                print(params) # TODO: Somehow pass this to the frontend and analyze it for patterns
                await self.__original_database_writer(batch, params)

            except asyncio.CancelledError:
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

        transport, protocol = await loop.create_datagram_endpoint(
            protocol_factory=lambda: server,
            local_addr=(server.host, server.port),
        )

        print("[INFO ][SYSLOG]Server is listening...")
        await stop_event.wait()

        print("[INFO ][SYSLOG]Shutting down custom server.")
        transport.close()
        await server.shutdown()

