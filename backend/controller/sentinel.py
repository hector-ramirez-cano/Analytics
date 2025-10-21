class Sentinel:
    """Sentinel singleton used to cleanly exit queues before shutting down

    Returns:
        _type_: singleton instance of Sentinel
    """

    __instance = None

    def __new__(cls):
        if cls.__instance is None:
            cls.__instance = super(Sentinel, cls).__new__(cls)

        return cls.__instance