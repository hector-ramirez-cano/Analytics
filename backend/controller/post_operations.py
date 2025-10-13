import json

from model.db.commit_changes import commit


async def api_configure(data: str) -> tuple[bool, str]:
    data: dict = json.loads(data)

    return await commit(data)
