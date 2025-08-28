SELECT * FROM Analytics.items;
SELECT * FROM Analytics.devices;
SELECT * FROM Analytics.links;
SELECT * FROM Analytics.groups;
SELECT * FROM Analytics.group_members;



INSERT INTO Analytics.devices (device_id, device_name, position_x, position_y, latitude, longitude, management_hostname, requested_metadata) 
    VALUES 
        (1, 'Xochimilco-lan',  0.5,  0.5, 21.159425, -101.645852, '192.168.100.3', '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]'),
        (2, 'Tlatelolco-lan',  0.7, -0.2, 21.159425, -101.645852, '192.168.100.5', '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]'),
        (3, 'Obsidian-lan'  , -0.3 , 0.3, 21.159425, -101.645852, '10.144.1.225'   , '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]');

UPDATE Analytics.devices SET requested_metadata = '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]'; 
UPDATE Analytics.devices SET management_hostname = '10.144.1.222' where device_id = 1;
UPDATE Analytics.devices SET management_hostname = '10.144.1.1' where device_id = 2;
UPDATE Analytics.devices SET management_hostname = '10.144.1.1' where device_id = 3;
UPDATE Analytics.devices SET metadata = NULL;

INSERT INTO Analytics.links (link_id, side_a, side_b, link_type)
    VALUES 
        (100, 1, 2, 'copper'),
        (101, 1, 3, 'copper'),
        (102, 2, 3, 'wireless');

INSERT INTO Analytics.groups (group_id, group_name, is_display_group) 
    VALUES
        (201, 'Routers', 0<>0),
        (202, 'Hosts', 0<>1);

UPDATE Analytics.groups SET is_display_group=0<>1 WHERE group_id = 202;

INSERT INTO Analytics.group_members(group_id, device_id)
    VALUES
        (201, 1),
        (201, 2),
        (202, 3);

