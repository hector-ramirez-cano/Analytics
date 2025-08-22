import ansible_runner

import backend.Config as Config
from backend.model.db import update_device_metadata


async def query_facts_from_inventory():

    print("[INFO]Gathering facts")
    config    = Config.Config()
    playbook  = config.get_or_default("backend/model/playbooks/fact_gathering")
    private   = config.get_or_default("backend/model/private_data_dir")
    inventory = config.get_or_default("backend/model/inventory")

    with open(inventory) as inventory_file:
        inventory = inventory_file.read()

    runner = ansible_runner.run(private_data_dir=private, playbook=playbook, inventory=inventory, quiet=True)

    metrics = {}

    # Extract metrics into dictionary, for easy access
    for event in runner.events:
        if event['event'] == 'runner_on_ok':
            host = event['event_data']['host']
            res = event['event_data']['res']

            if 'ansible_facts' in res:
                metrics.setdefault(host, {}).update(res['ansible_facts'])

    await update_device_metadata(metrics)
