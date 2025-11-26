import json
import os
from logging import Logger


def __resolve_imports__(config_dict: dict, depth_limit: int = 5):
    """
    Resolves imports inside json documents, where a $ref field references another json document.
    :param config_dict dict representation of the json file
    :param depth_limit int depth limit in resolve nesting
    """
    pending_dicts_stack = [config_dict]
    depth = 0

    while len(pending_dicts_stack) > 0 and depth < depth_limit:
        current = pending_dicts_stack.pop()

        # add this level's dictionaries to the stack
        pending_dicts_stack += [current[key] for key in current if isinstance(current[key], dict)]

        if "$ref" in current:
            depth += 1

            # Remove the headless item
            # append in-place. If an item is defined both in the parent and in the import, import prevails
            path = current.pop("$ref")
            current |= Config.__parse__(path, resolve_imports = False)

            # add this level's dictionaries to the stack, for recursive imports
            pending_dicts_stack += [current[key] for key in current if isinstance(current[key], dict)]

    if depth < depth_limit:
        return config_dict

    else:
        Logger(name="Config").critical(msg=(f"[CRITICAL]Config file exceeds import depth. depth_limit={depth_limit}"))
        raise Exception(f"[CRITICAL]Config file exceeds import depth. depth_limit={depth_limit}")


class Config(object):
    __instance = None

    config = None

    def __new__(cls):
        if cls.__instance is None:
            cls.__instance = super(Config, cls).__new__(cls)
            cls.__instance.config = cls.__parse__("config.json")

        return cls.__instance


    @staticmethod
    def __parse__(path: str, resolve_imports = True):
        tmp = None
        with open(path, encoding="utf-8") as config_file:
            tmp = json.load(config_file)

            config_file.close()

        if os.getenv("NDEBUG"):
            print("[PRELUDE][INFO ] Loaded release config")
            tmp = tmp["release"]
        else:
            print("[PRELUDE][INFO ] Loaded debug config")
            tmp = tmp["debug"]

        if resolve_imports:
            __resolve_imports__(tmp)

        return tmp


    @staticmethod
    def get(path, default=None, sep="/"):
        """
        Get a nested value from a dict using a path string.

        :param path: str, e.g. "api/config/details/value"
        :param default: value to return if path not found
        :param sep: separator for path (default: "/")
        :return: value at path or default

        Example:
        {
        "api": { "config": { "details": { "value": 42 } } }
        }

        value = get(data, "api/config/details/value") # -> 42

        missing = get(data, "api/config/details/missing", default="not found") # -> "not found"
        """
        if Config.__instance is None:
            Config()

        keys = path.split(sep)
        current = Config.__instance.config
        try:
            for key in keys:
                current = current[key]
            return current
        except (KeyError, TypeError):
            Logger(name="Config").error(msg="Using undefined config value '"+path+"', returning default value," + str(default))
            return default

    @staticmethod
    def has(path: str) -> bool:
        """
        Checks if a nested value is found in the config using a path string.

        :param path: str, e.g. "api/config/details/value"
        :return: whether the item is found in the config files
        """
        sentinel = object()
        return Config.get(path, sentinel) != sentinel

config = Config()
