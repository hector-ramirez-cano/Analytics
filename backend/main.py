import os

import Config
from backend.model.db import init_db_pool
from controller import server


def init():
    # TODO: Replace with Logger
    print("[INFO]CWD=", os.getcwd())

def main():
    init()

    config = Config.Config()
    init_db_pool()
    port = config.config["backend"]["controller"]["port"]

    server.app.run(debug=True, port=port)


if __name__ == "__main__":
    main()