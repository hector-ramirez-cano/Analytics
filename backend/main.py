import os

import Config
from controller import server


def init():
    # TODO: Replace with Logger
    print("[INFO]CWD=", os.getcwd())

def main():
    init()

    config = Config.Config()

    port = config.config["backend"]["controller"]["port"]

    server.app.run(debug=True, port=port)


if __name__ == "__main__":
    main()