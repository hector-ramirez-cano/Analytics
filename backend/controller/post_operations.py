import json

from model.db.commit_changes import commit


async def api_configure(data: bytes) -> tuple[bool, str]:
    data: dict = json.loads(data.decode('utf-8'))

    return await commit(data)
