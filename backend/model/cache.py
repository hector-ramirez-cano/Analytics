import time

from backend.Config import Config


class Cache(object):

    __devices : dict = {}
    __links   : list = ()
    __groups  : list = ()

    __last_update = 0 # Epoch

    @property
    def ansible_inventory(self) -> str:
        """
        Converts the device dictionary into an ansible compliant inventory, without the header
        Currently, it only returns a management_hostname per line only
        """
        ansible_devices = [device_id for device_id in self.devices if "ssh" in self.devices[device_id].configuration.data_sources]
        return "\n".join([self.devices[device_id].management_hostname for device_id in ansible_devices])

    @property
    def icmp_inventory(self) -> list:
        """
        Converts the device dictionary into an ansible compliant inventory, without the header
        Currently, it only returns a management_hostname per line only
        """
        icmp_devices = [device_id for device_id in self.devices if "icmp" in self.devices[device_id].configuration.data_sources]
        return [self.devices[device_id].management_hostname for device_id in icmp_devices]


    @property
    def devices(self):
        return self.__devices

    @property
    def links(self):
        return self.__links

    @property
    def groups(self):
        return self.__groups

    @property
    def topology(self):
        return [self.__devices, self.__links, self.__groups]

    @property
    def should_update(self):
        return time.time() - self.__last_update > Config.get_or_default("backend/controller/cache/cache_invalidation_s", 60)

    @property
    def last_update(self):
        return self.__last_update

    @devices.setter
    def devices(self, devices):
        self.__last_update = time.time()
        self.__devices = devices

    @links.setter
    def links(self, links):
        self.__last_update = time.time()
        self.__links = links

    @groups.setter
    def groups(self, groups):
        self.__groups = groups
        self.__last_update = time.time()


    def update(self, devices, links, groups):
        self.__devices = devices
        self.__links = links
        self.__groups = groups

        self.__last_update = time.time()

cache = Cache()