SELECT * FROM Analytics.items;
SELECT * FROM Analytics.devices;
SELECT * FROM Analytics.links;
SELECT * FROM Analytics.groups;
SELECT * FROM Analytics.group_members;
SELECT device_id, data_source FROM Analytics.device_data_sources;

SELECT * FROM Analytics.devices;

UPDATE Analytics.devices SET available_values = NULL;

SELECT requested_metadata from Analytics.devices WHERE device_id = 1;

SELECT Analytics.devices.device_id, device_name, position_x, position_y, latitude, longitude, management_hostname, requested_metadata, available_values 
                FROM Analytics.devices;

INSERT INTO Analytics.devices (device_id, device_name, position_x, position_y, latitude, longitude, management_hostname, requested_metadata, requested_metrics) 
    VALUES 
        (1, 'Xochimilco-lan',  0.5,  0.5, 21.159425, -101.645852, '10.144.1.222' , '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]'),
        (2, 'Tlatelolco-lan',  0.7, -0.2, 21.159425, -101.645852, '10.144.1.1'   , '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]'),
        (3, 'Obsidian-lan'  , -0.3 , 0.3, 21.159425, -101.645852, '10.144.1.225' , '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]');

SELECT * FROM Analytics.device_data_sources;
INSERT INTO Analytics.device_data_sources (device_id, data_source)
    VALUES
        (1, 'icmp'),
        (1, 'ssh'),
        (2, 'icmp'),
        (2, 'ssh'),
        (2, 'snmp'),
        (3, 'icmp');

SELECT * FROM Analytics.devices;
UPDATE Analytics.devices SET management_hostname = '10.144.1.222' where device_id = 1;
UPDATE Analytics.devices SET management_hostname = '10.144.1.1' where device_id = 2;
UPDATE Analytics.devices SET management_hostname = '10.144.1.225' where device_id = 3;
UPDATE Analytics.devices SET metadata = NULL;

INSERT INTO Analytics.links (link_id, side_a, side_b, side_a_iface, side_b_iface, link_type)
    VALUES 
        (100, 1, 2, 'eth0', 'eth0', 'copper'),
        (101, 1, 3, 'eth0', 'eth0', 'copper'),
        (102, 2, 3, 'eth0', 'eth0', 'wireless');

SELECT * FROM Analytics.groups;
INSERT INTO  (group_id, group_name, is_display_group) 
    VALUES
        (201, 'Routers', 0<>0),
        (202, 'Hosts', 0<>1);
INSERT INTO Analytics.groups (group_id, group_name, is_display_group) 
    VALUES
        (203, 'Raíz', 0<>1);

UPDATE Analytics.groups SET is_display_group=0<>1 WHERE group_id = 202;

SELECT * FROM Analytics.group_members;
INSERT INTO Analytics.group_members(group_id, item_id)
    VALUES
        (201, 1),
        (201, 2),
        (202, 3);

INSERT INTO Analytics.group_members(group_id, item_id)
    VALUES
        (203, 201),
        (203, 202);

INSERT INTO Analytics.dashboard(dashboard_id, dashboard_name)
    VALUES
        (1, 'Default Dashboard');

-- TRUNCATE Analytics.dashboard_items;
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition)
    VALUES
        (1, 0, 1, 0, 3, '{"start":"-1h", "aggregate-interval-s": 60, "update-interval-s": 60, "field":"icmp_rtt", "device-ids":1, "type": "metric", "chart-type":"line"}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition)
    VALUES
        (1, 1, 1, 0, 1, '{"update-interval-s": 60, "field":"icmp_rtt", "device-ids":1, "type":"metadata", "chart-type": "label"}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition)
    VALUES
        (1, 1, 1, 1, 1, '{"update-interval-s": 60, "field":"icmp_status", "device-ids":203, "type":"metadata", "chart-type": "pie"}');

-- TODO: Handle actual parent-child recursion
-- INSERT INTO Analytics.group_members(group_id, item_id) VALUES (203, 203);

TRUNCATE Analytics.alert_rules;

-- TRUNCATE Analytics.alert_rules;
INSERT INTO Analytics.alert_rules (rule_id, rule_name, requires_ack, rule_definition)
    VALUES (1, 'ICMP_RTT > 500ms', TRUE, '{"severity":"warning","target":1,"reduce-logic": "all","source":"facts","predicates":[{"left":"&icmp_rtt","op":"more_than","right":60}]}');

SELECT * FROM Analytics.alert_rules;

SELECT * FROM Analytics.alerts;
-- TRUNCATE Analytics.alerts;

SELECT count(1) AS count FROM Analytics.alerts OFFSET 0;

-- DROP TABLE Analytics.telegram_receiver;
-- TRUNCATE Analytics.telegram_receiver;
select * from Analytics.telegram_receiver;
INSERT INTO Analytics.telegram_receiver(telegram_user_id, authenticated, subscribed) 
VALUES (6879383639, TRUE, TRUE) 
ON CONFLICT(telegram_user_id) 
    DO UPDATE SET authenticated = TRUE WHERE Analytics.telegram_receiver.telegram_user_id = 1;

