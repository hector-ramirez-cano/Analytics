import asyncio

from backend.model import db
from backend.model.fact_gathering import snmp_backend, icmp_backend, ansible_backend


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


async def gather_all_facts():

    await db.update_topology_cache()
    print("[INFO ]Gathering facts")

    tasks = [
        icmp_backend.gather_facts(),
        snmp_backend.gather_facts(),
        ansible_backend.gather_facts(),
    ]

    results = await asyncio.gather(*tasks)

    # merge results and stats
    metrics, status = __merge_results(results)
    exposed_fields = __get_exposed_fields(metrics)


    # Update database
    metadata  = db.update_device_metadata(exposed_fields, metrics, status)
    analytics = db.update_device_analytics(metrics)

    await metadata
    await analytics

    return metrics, status