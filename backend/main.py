import os

import Config
from backend.model.db import init_db_pool
from backend.controller import server


def init():
    # TODO: Replace with Logger
    print("[INFO ]CWD=", os.getcwd())


def main():
    init()

    config = Config.config
    init_db_pool()
    port = config.get_or_default("backend/controller/api/port", 5050)

    is_debug =os.environ.get("DEBUG") == "1"
    print("[DEBUG]is_debug=",is_debug)

    server.app.run(debug=is_debug, port=port, host="0.0.0.0")


if __name__ == "__main__":
    main()