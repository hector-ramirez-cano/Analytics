import sys

import ansible_runner

import backend.Config as Config
from backend.model.db import update_device_metadata
from backend.model.device_state import DeviceStatus, DeviceState


async def query_facts_from_inventory():
    print("[INFO ]Gathering facts")
    config    = Config.Config()
    playbook  = config.get_or_default("backend/model/playbooks/fact_gathering")
    private   = config.get_or_default("backend/model/private_data_dir")
    inventory = config.get_or_default("backend/model/inventory")

    # TODO: Generate inventory from DB
    with open(inventory) as inventory_file:
        inventory = inventory_file.read()

    runner = ansible_runner.run(
        private_data_dir= private,
        playbook        = playbook,
        inventory       = inventory,
        artifact_dir    = None,
        quiet           = True
    )

    metrics = {}
    stats = {}

    # Extract metrics into dictionary, for easy access
    for event in runner.events:
        if event['event'] == 'runner_on_ok':
            host = event['event_data']['host']
            res = event['event_data']['res']

            if 'ansible_facts' in res:
                metrics.setdefault(host, {}).update(res['ansible_facts'])

            # Set status only if it hasn't failed
            if stats.get(host) is None:
                stats[host] = DeviceStatus(DeviceState.REACHABLE, msg="")

        if event['event'] == 'runner_on_unreachable':
            host = event['event_data']['host']
            res = event['event_data']['res']

            # Override status
            stats[host] = DeviceStatus(DeviceState.DARK, msg=res['msg'])

    print("[INFO ]Ansible playbook finished with the following stats: ", runner.stats)

    await update_device_metadata(metrics, stats)
