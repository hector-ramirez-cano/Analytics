import json
from logging import Logger


def __resolve_imports__(config: dict):
    pending_dicts_stack = [config]
    depth = 0
    depth_limit = 5

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
        return config

    else:
        Logger(name="Config").critical(msg=("[CRITICAL]Config file exceeds import depth. depth_limit="+str(depth_limit)))
        raise Exception("[CRITICAL]Config file exceeds import depth. depth_limit="+str(depth_limit))


class Config(object):
    __instance = None

    config = None

    def __new__(cls):
        if cls.__instance is None:
            cls.__instance = super(Config, cls).__new__(cls)
            cls.__instance.config = cls.__parse__("backend/config.json")

        return cls.__instance


    @staticmethod
    def __parse__(path: str, resolve_imports = True):
        config = None
        with open(path, encoding="utf-8") as config_file:
            config = json.load(config_file)

            config_file.close()

        if resolve_imports:
            __resolve_imports__(config)

        return config


    @staticmethod
    def get_or_default(path, default=None, sep="/"):
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

        value = AppConfig.get_config(data, "api/config/details/value") # -> 42

        missing = AppConfig.get_config(data, "api/config/details/missing", default="not found") # -> "not found"
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

config = Config()