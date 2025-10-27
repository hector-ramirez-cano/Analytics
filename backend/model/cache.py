import time
import copy

from typing import Set

from Config import Config
from model.data.device import Device
from model.data.group import Group


class Cache(object):
    __instance = None

    def __new__(cls):
        if cls.__instance is None:
            cls.__instance = super(Cache, cls).__new__(cls)

        return cls.__instance

    __devices : dict = {}
    __links   : dict = {}
    __groups  : dict = {}

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
    def devices(self) -> dict:
        """Getter for devices

        Returns:
            dict: dictionary of devices with the itemId as key
        """
        return self.__devices

    @property
    def links(self) -> dict:
        """Getter for links

        Returns:
            dict: dictionary of links with the itemId as key
        """
        return self.__links

    @property
    def groups(self) -> dict:
        """Getter for groups

        Returns:
            dict: dictionary of groups with the itemId as key
        """
        return self.__groups

    @property
    def topology(self) -> tuple:
        """Returns a tuple containing the dict of devices, dict of links and dict of groups, as viewed by the cache

        Returns:
            tuple: topology as tuple
        """
        return self.__devices, self.__links, self.__groups

    @property
    def should_update(self) -> bool:
        """Returns whether the time since last update is greater than the cache_invalidation_s config var, and thus, whether the cache should be updated

        Returns:
            bool: should update?
        """
        return time.time() - self.__last_update > Config.get("backend/controller/cache/cache_invalidation_s", 60)

    @property
    def last_update(self) -> float:
        """Returns when the last update was performed, in Unix timestamp

        Returns:
            float: UnixTimestamp
        """
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

        self.purge_cyclic_references(groups)



    def get_item(self, item_id: int) -> Device | Group | None:
        """Retrieves an item from the cache, whether it be a group or a device

        Args:
            item_id (int): unique id of the item to be returned

        Returns:
            Device | Group | None: Item as stored in cache, or None if not found
        """
        return self.__devices.get(item_id, self.__groups.get(item_id, None))

    def get_group(self, item_id: int) -> Group | None:
        """Retrieves a  group from the cache

        Args:
            item_id (int): unique id of the group to be returned

        Returns:
            Group | None: Group as stored in cache
        """
        return self.__groups.get(item_id, None)

    def get_device(self, item_id: int) -> Group | None:
        """Retrieves a device from the cahce

        Args:
            item_id (int): unique id of the device to be returned

        Returns:
            Group | None: Device as stored in cache, or None if not found
        """
        return self.__devices.get(item_id, None)

    def get_devices_in_group(self, group_id: int) -> Set[Device]:
        """Recursively returns the devices inside a group. If the group contains another group, the devices inside the inner group are also returned.

        Args:
            group_id (int): unique id of a group.

        Returns:
            Set[Device]: Set of devices inside the group. If the groupId param does not map to a group, an empty set will be returned
        """
        group = self.get_group(group_id)

        if group is None:
            return {}

        result = set()
        for member_id in group.members:
            member = self.get_item(member_id)

            if isinstance(member, Device):
                result.add(member)

            if isinstance(member, Group):
                # recursive search
                for inner in self.get_devices_in_group(member_id):
                    result.add(inner)

        return result

    def purge_cyclic_references(self, groups: dict):
        """Iterates over all the groups, and calls for the removal of cyclic references

        Args:
            groups (dict): Removes cyclic references all devices
        """
        for group_id in groups:
            parents = set()
            group = self.get_item(group_id)
            self.purge_single_cyclic_references(group, parents)


    def purge_single_cyclic_references(self, group: Group, parents : set) -> bool:
        """Recusively goes through each group and removes any cyclic references found. This is a last resort, in case the database enters an inconsistent state

        Args:
            group (Group): Group to inspect
            parents (set): Set of parents containing this group, in any vertical form

        Returns:
            bool: whether a cyclic reference was found
        """

        if group.group_id in parents:
            # group has already been tried in this line, it means there's a cyclic reference
            # we need to remove the group from the parent
            print("[ERRRO][CACHE]Found group with cyclic reference, removed cyclic reference from top-bottom")
            return False

        # add group to visited groups
        parents.add(group.group_id)

        group_members = [member for member in group.members if isinstance(self.get_item(member), Group)]

        for group_id in group_members:
            inner_group = self.get_item(group_id)
            inner_parents = copy.deepcopy(parents)

            if not self.purge_single_cyclic_references(inner_group, inner_parents):
                # a children has notified us that it has already been visited
                # means we have a duplicate
                group.members.remove(group_id)

        return True



    def update(self, devices : dict[Device], links : dict, groups : dict[Group]):
        """Updates the cache information, and resets the time until next update

        Args:
            devices (dict[Device]): Dict of devices to be consumed into the cache
            links (dict[Link]): Dict of Links to be consumed into the cache
            groups (dict[Group]): Dict of groups to be consumed into the cache
        """
        self.__devices = devices
        self.__links = links
        self.__groups = groups
        self.purge_cyclic_references(groups)

        self.__last_update = time.time()
