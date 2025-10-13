import json

from flask import Response

from model.db.operations.syslog_operations import get_topology_as_json


def api_get_topology():
    topology = get_topology_as_json()
    topology = json.dumps(topology)
    return Response(topology, content_type="application/json")
    # return await send_from_directory(routes_dir, "test-data.json")