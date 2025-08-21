import json
from logging import Logger


class Config(object):
    __instance = None
    
    config = None

    def __new__(cls):
        if cls.__instance is None:
            cls.__instance = super(Config, cls).__new__(cls)

        with open("../config.json") as config_file:
            cls.__instance.config = json.load(config_file)
            
            config_file.close()

        return cls.__instance

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
        keys = path.split(sep)
        current = Config.__instance.config
        try:
            for key in keys:
                current = current[key]
            return current
        except (KeyError, TypeError):
            Logger(name="Config").error(msg="Using undefined config value '"+path+"', returning default value, $defaultVal")
            return default
