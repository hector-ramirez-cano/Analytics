import asyncio

from backend.model.db import update_topology_cache
from backend.model.fact_gathering import ansible_backend, icmp_backend, snmp_backend

def __recursive_merge(dict1, dict2):
    for key, value in dict2.items():
        if key in dict1 and isinstance(dict1[key], dict) and isinstance(value, dict):
            # Recursively merge nested dictionaries
            dict1[key] = __recursive_merge(dict1[key], value)
        else:
            # Merge non-dictionary values
            dict1[key] = value
    return dict1

def __merge_results(results):
    merged_metrics, merged_stats = {}, {}

    for result in results:
        if result is None:
            continue

        merged_metrics = __recursive_merge(merged_metrics, result[0])
        merged_stats = __recursive_merge(merged_stats, result[1])

    return merged_metrics, merged_stats


async def gather_all_facts():

    await update_topology_cache()
    print("[INFO ]Gathering facts")

    tasks = [
        # icmp_backend.gather_facts(),
        snmp_backend.gather_facts(),
        # ansible_backend.gather_facts(),
    ]

    results = await asyncio.gather(*tasks)

    # merge results and stats
    merged_metrics, merged_stats = __merge_results(results)

    return merged_metrics, merged_stats