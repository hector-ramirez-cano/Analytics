
import asyncio

from backend.Config import Config
from backend.model.db.update_devices import update_topology_cache, update_device_metadata, update_device_analytics
from backend.model.fact_gathering.ansible import ansible_backend
from backend.model.fact_gathering.snmp import snmp_backend
from backend.model.fact_gathering.icmp import icmp_backend

def __recursive_merge(dict1, dict2):
    for key, value in dict2.items():
        if key in dict1 and isinstance(dict1[key], dict) and isinstance(value, dict):
            # Recursively merge nested dictionaries
            dict1[key] = __recursive_merge(dict1[key], value)
        else:
            # Merge non-dictionary values
            dict1[key] = value
    return dict1


def __merge_results(results) -> tuple[dict, dict]:
    """
    Merges metrics and status from a list of results, with correspondence of information among different data sources

    return exposed_metrics, metrics, status
    """
    merged_metrics, merged_status = {}, {}

    for result in results:
        if result is None:
            continue

        merged_metrics = __recursive_merge(merged_metrics, result[0])
        merged_status = __recursive_merge(merged_status, result[1])

    return merged_metrics, merged_status


def __get_exposed_fields(metrics: dict) -> dict:
    exposed_metrics = {}
    for key, value in metrics.items():
        exposed_metrics [key] = list(value)

    return exposed_metrics


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
    metrics, status = await loop.run_in_executor(None, __merge_results, results)
    exposed_fields  = await loop.run_in_executor(None, __get_exposed_fields, metrics)

    return exposed_fields, metrics, status


async def __update_db_with_facts(exposed_fields, metrics, status):
    loop = asyncio.get_running_loop()

    # Update database
    await  loop.run_in_executor(None, update_topology_cache, )

    metadata  = loop.run_in_executor(None, update_device_metadata, exposed_fields, metrics, status)
    analytics = loop.run_in_executor(None, update_device_analytics, metrics)

    await metadata
    await analytics


async def gather_facts_task(stop_event: asyncio.Event):

    while not stop_event.is_set():

        try:
            # timeout
            timeout = Config.get("backend/controller/fact-gathering/polling_time_s", 5)
            await asyncio.wait_for(stop_event.wait(),  timeout)

        except asyncio.TimeoutError:

            # Gather facts - non-blocking
            exposed_fields, metrics, status = await __gather_all_facts()

            # Update the database
            await __update_db_with_facts(exposed_fields, metrics, status)

    print("[INFO][FACTS]Shutting down fact gathering loop!")
