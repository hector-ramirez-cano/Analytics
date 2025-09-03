import ansible_runner

import backend.Config as Config
from backend.model.ansible_status import AnsibleStatus
from backend.model.device_state import DeviceStatus
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
                status[host] = DeviceStatus(ansible_status=AnsibleStatus.REACHABLE, msg="")

        if event['event'] == 'runner_on_unreachable':
            host = event['event_data']['host']
            res = event['event_data']['res']

            # Override status
            status[host] = DeviceStatus(ansible_status=AnsibleStatus.DARK, msg=res['msg'])

    return metrics, status


def __run_fact_gathering_playbook() -> tuple[dict, dict]:
    """
    Calls to execution the gather_facts playbook

    :returns exposed_metrics, metric, status
    """
    config = Config.config
    playbook = config.get_or_default("backend/model/playbooks/fact_gathering")
    private = config.get_or_default("backend/model/private_data_dir")

    inventory = "[servers]\n" + cache.ansible_inventory

    runner = ansible_runner.run(
        private_data_dir=private,
        playbook=playbook,
        inventory=inventory,
        artifact_dir=None,
        quiet=True
    )

    print("[INFO ]Ansible playbook finished with the following stats: ", runner.stats)
    return __extract_facts_from_playbook(runner)


# TODO: Refactor this function into multiple smaller functions for readability
async def gather_facts():
    """
    Calls to ansible ro execute the gather_facts playbook upon the devices found on cache that match
    with "ssh" in data_sources.

    Calls to update metadata and analytics to PostgresDB and InfluxDB respectively
    """

    # TODO: Make this function faster

    metrics, status = __run_fact_gathering_playbook()

    return metrics, status