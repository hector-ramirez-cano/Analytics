import ansible_runner

import src.Config

async def insert_device_metadata(metrics):
    """
    Inserts data that might change infrequently into the Postgres database
    :return: None
    """


async def query_facts_from_inventory():

    print("[INFO]Gathering facts")
    config    = src.Config.Config()
    playbook  = config.get_or_default("backend/model/playbooks/fact_gathering")
    private   = config.get_or_default("backend/model/private_data_dir")
    inventory = config.get_or_default("backend/model/inventory")

    with open(inventory) as inventory_file:
        inventory = inventory_file.read()

    runner    = ansible_runner.run(private_data_dir=private, playbook=playbook, inventory=inventory)

    print(runner.get_fact_cache("all"))

    metrics = {}

    for event in runner.events:
        if event['event'] == 'runner_on_ok':
            host = event['event_data']['host']
            res = event['event_data']['res']

            if 'ansible_facts' in res:
                metrics.setdefault(host, {}).update(res['ansible_facts'])

    print(metrics)
