import asyncio

from psycopg_pool import PoolTimeout

from Config import Config
from model.db.update_devices import update_topology_cache
from model.db.update_devices import update_device_metadata
from model.db.update_devices import update_device_analytics
from model.facts.ansible import ansible_backend
from model.facts.snmp import snmp_backend
from model.facts.icmp import icmp_backend


class FactGatheringBackend:
    instance = None
    listeners = []

    def __new__(cls, *_, **__):
        if cls.instance is None:
            cls.instance = super(FactGatheringBackend, cls).__new__(cls)
            cls.instance.listeners = []

        return cls.instance

    @staticmethod
    def init():
        FactGatheringBackend()

    @staticmethod
    def register_listener(queue: asyncio.Queue[dict]):
        FactGatheringBackend().instance.listeners.append(queue)

    @staticmethod
    async def notify_listeners(metrics: dict):
        for listener in FactGatheringBackend().listeners:
            await listener.put(metrics)


    @staticmethod
    def __recursive_merge(dict1, dict2):
        for key, value in dict2.items():
            if key in dict1 and isinstance(dict1[key], dict) and isinstance(value, dict):
                # Recursively merge nested dictionaries
                dict1[key] = FactGatheringBackend.__recursive_merge(dict1[key], value)
            else:
                # Merge non-dictionary values
                dict1[key] = value
        return dict1

    @staticmethod
    def __merge_results(results) -> tuple[dict, dict]:
        """
        Merges metrics and status from a list of results, 
        with correspondence of information among different data sources

        return exposed_metrics, metrics, status
        """
        merged_metrics, merged_status = {}, {}

        for result in results:
            if result is None:
                continue

            merged_metrics = FactGatheringBackend.__recursive_merge(merged_metrics, result[0])
            merged_status  = FactGatheringBackend.__recursive_merge(merged_status, result[1])

        return merged_metrics, merged_status

    @staticmethod
    def __get_exposed_fields(metrics: dict) -> dict:
        exposed_metrics = {}
        for key, value in metrics.items():
            exposed_metrics [key] = list(value)

        return exposed_metrics

    @staticmethod
    async def __gather_all_facts():
        loop = asyncio.get_running_loop()

        loop.run_in_executor(None, update_topology_cache)
        print("[INFO ]Gathering facts")

        tasks = [
            icmp_backend.gather_facts(),
            snmp_backend.gather_facts(),
            ansible_backend.gather_facts(),
        ]

        # Non-blocking tasks
        results = await asyncio.gather(*tasks)

        # merge results and stats
        metrics, status = await loop.run_in_executor(None, 
                                    FactGatheringBackend.__merge_results, results)

        exposed_fields  = await loop.run_in_executor(None,
                                    FactGatheringBackend.__get_exposed_fields, metrics)

        return exposed_fields, metrics, status

    @staticmethod
    async def __update_db_with_facts(exposed_fields, metrics, status):
        loop = asyncio.get_running_loop()

        # Update database
        await  loop.run_in_executor(None, update_topology_cache, )

        metadata  = loop.run_in_executor(None, update_device_metadata,exposed_fields,metrics,status)
        analytics = loop.run_in_executor(None, update_device_analytics, metrics)

        await metadata
        await analytics

    @staticmethod
    async def update(stop_event: asyncio.Event, data_queue: asyncio.Queue[tuple]):
        while not stop_event.is_set():
            exposed_fields, metrics, status = await data_queue.get()

            try:
                # Update the database, main listener
                await FactGatheringBackend.__update_db_with_facts(exposed_fields, metrics, status)

                # Update external listeners
                await FactGatheringBackend.notify_listeners(metrics)

            except PoolTimeout as _:
                await data_queue.put(exposed_fields)

            except Exception as e:
                # pylint: disable=broad-exception-caught
                print(f"[ERROR][FACTS]e={e}")

    @staticmethod
    async def gather_facts_task(stop_event: asyncio.Event, data_queue: asyncio.Queue[tuple]):
        # TODO: Change to respond faster to stop_event, as done in alerts
        while not stop_event.is_set():
            try:
                # Gather facts - non-blocking
                exposed_fields, metrics, status = await FactGatheringBackend.__gather_all_facts()

                # pass data into data queue for writing
                await data_queue.put((exposed_fields, metrics, status))

            except PoolTimeout as _:
                pass
            except Exception as e: # pylint: disable=W0718
                print(f"[ERROR][FACTS]registered exception e='{str(e)}'")

            try:
                # timeout
                timeout = Config.get("backend/controller/fact-gathering/polling_time_s", 5)
                await asyncio.wait_for(stop_event.wait(),  timeout)

            except asyncio.TimeoutError:
                pass

            except Exception as e:
                print(f"[ERROR][FACTS]registered exception e='{str(e)}'")


        print("[INFO][FACTS]Shutting down fact gathering loop!")
