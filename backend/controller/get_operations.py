import json

from flask import Response

from model.db.fetch_topology import get_topology_as_json


def api_get_topology():
    topology = get_topology_as_json()
    topology = json.dumps(topology)
    return Response(topology, content_type="application/json")
