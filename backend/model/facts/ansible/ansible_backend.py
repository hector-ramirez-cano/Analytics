import asyncio

import ansible_runner

import backend.Config as Config
from backend.model.ansible_status import AnsibleStatus
from backend.model.cache import cache

def __extract_facts_from_playbook(runner) -> tuple[dict, dict]:
    """
    Extracts metadata acquired from devices after executing the gather facts playbook

    :returns metrics, status
    """
    metrics = {}
    status = {}
    # Extract metrics into dictionary, for easy access
    for event in runner.events:
        if event['event'] == 'runner_on_ok':
            host = event['event_data']['host']
            res = event['event_data']['res']

            if 'ansible_facts' in res:
                metrics.setdefault(host, {}).update(res['ansible_facts'])

            # Set status only if it hasn't failed
            if status.get(host) is None:
                status[host] = { "ansible_status": {"status": AnsibleStatus.REACHABLE, "msg": ""} }

        if event['event'] == 'runner_on_unreachable':
            host = event['event_data']['host']
            res = event['event_data']['res']

            # Override status
            status[host] = {"ansible_status": {"status": AnsibleStatus.DARK, "msg": res['msg']}}

    return metrics, status


def __run_fact_gathering_playbook() -> tuple[dict, dict]:
    """
    Calls to execution the gather_facts playbook

    :returns exposed_metrics, metric, status
    """
    config = Config.config
    playbook = config.get("backend/model/playbooks/fact_gathering")
    private = config.get("backend/model/private_data_dir")

    inventory = "[servers]\n" + cache.ansible_inventory

    print("[INFO ][FACTS][ANSIBLE]Starting playbook execution")
    runner = ansible_runner.run(
        private_data_dir=private,
        playbook=playbook,
        inventory=inventory,
        artifact_dir=None,
        quiet=True
    )

    print("[INFO ][FACTS][ANSIBLE]Ansible playbook finished with the following stats: ", runner.stats)
    return __extract_facts_from_playbook(runner)


async def gather_facts():
    """
    Calls to ansible ro execute the gather_facts playbook upon the devices found on cache that match
    with "ssh" in data_sources.

    Calls to update metadata and analytics to PostgresDB and InfluxDB respectively
    """
    loop = asyncio.get_running_loop()

    print("[INFO ][FACTS][ANSIBLE]Starting ansible fact gathering")

    # noinspection PyArgumentList
    metrics, status = await loop.run_in_executor(None, __run_fact_gathering_playbook)

    return metrics, status