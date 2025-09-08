SELECT * FROM Analytics.items;
SELECT * FROM Analytics.devices;
SELECT * FROM Analytics.links;
SELECT * FROM Analytics.groups;
SELECT * FROM Analytics.group_members;
SELECT device_id, data_source FROM Analytics.device_data_sources;

SELECT * FROM Analytics.devices JOIN Analytics.device_configuration ON Analytics.devices.device_id = Analytics.device_configuration.device_id;

SELECT Analytics.devices.device_id, device_name, position_x, position_y, latitude, longitude, management_hostname, requested_metadata, available_values 
                FROM Analytics.devices
                JOIN Analytics.device_configuration ON Analytics.devices.device_id = Analytics.device_configuration.device_id;

INSERT INTO Analytics.devices (device_id, device_name, position_x, position_y, latitude, longitude, management_hostname) 
    VALUES 
        (1, 'Xochimilco-lan',  0.5,  0.5, 21.159425, -101.645852, '192.168.100.3'),
        (2, 'Tlatelolco-lan',  0.7, -0.2, 21.159425, -101.645852, '192.168.100.5'),
        (3, 'Obsidian-lan'  , -0.3 , 0.3, 21.159425, -101.645852, '10.144.1.225' );

INSERT INTO Analytics.device_configuration (device_id, requested_metadata, requested_metrics)
    VALUES
        (1, '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]'),
        (2, '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]'),
        (3, '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]');

INSERT INTO Analytics.device_data_sources (device_id, data_source)
    VALUES
        (1, 'icmp'),
        (1, 'ssh'),
        (2, 'icmp'),
        (2, 'ssh'),
        (2, 'snmp'),
        (3, 'icmp');

UPDATE Analytics.devices SET management_hostname = '10.144.1.222' where device_id = 1;
UPDATE Analytics.devices SET management_hostname = '10.144.1.1' where device_id = 2;
UPDATE Analytics.devices SET management_hostname = '10.144.1.1' where device_id = 3;
UPDATE Analytics.devices SET metadata = NULL;

INSERT INTO Analytics.links (link_id, side_a, side_b, side_a_iface, side_b_iface, link_type)
    VALUES 
        (100, 1, 2, 'eth0', 'eth0', 'copper'),
        (101, 1, 3, 'eth0', 'eth0', 'copper'),
        (102, 2, 3, 'eth0', 'eth0', 'wireless');

INSERT INTO Analytics.groups (group_id, group_name, is_display_group) 
    VALUES
        (201, 'Routers', 0<>0),
        (202, 'Hosts', 0<>1);
INSERT INTO Analytics.groups (group_id, group_name, is_display_group) 
    VALUES
        (203, 'Raíz', 0<>1);

UPDATE Analytics.groups SET is_display_group=0<>1 WHERE group_id = 202;

INSERT INTO Analytics.group_members(group_id, item_id)
    VALUES
        (201, 1),
        (201, 2),
        (202, 3);

INSERT INTO Analytics.group_members(group_id, item_id)
    VALUES
        (203, 201),
        (203, 202);

// Should fail, a group cant contain itself
// TODO: Handle actual parent-child recursion
// INSERT INTO Analytics.group_members(group_id, item_id) VALUES (203, 203);