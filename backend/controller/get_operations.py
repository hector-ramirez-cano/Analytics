import json

from flask import Response

from model.db.fetch_topology import get_topology_as_dict
from model.db.operations.alert_operations import get_rules_as_list



def api_get_topology():
    topology = get_topology_as_dict()
    topology = json.dumps(topology)
    return Response(topology, content_type="application/json")


def api_get_rules():
    rules = get_rules_as_list()
    rules = json.dumps(rules)

    return Response(rules, content_type="application/json")

