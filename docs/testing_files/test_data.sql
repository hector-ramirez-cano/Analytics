SELECT * FROM Analytics.items;
SELECT * FROM Analytics.devices;
SELECT * FROM Analytics.links;
SELECT * FROM Analytics.groups;
SELECT * FROM Analytics.group_members;
SELECT device_id, data_source FROM Analytics.device_data_sources;

SELECT * FROM Analytics.devices;
SELECT * FROM Analytics.device_data_sources;

UPDATE Analytics.devices SET available_values = NULL;

SELECT requested_metadata from Analytics.devices WHERE device_id = 1;

SELECT Analytics.devices.device_id, device_name, latitude, longitude, management_hostname, requested_metadata, available_values 
                FROM Analytics.devices;


INSERT INTO Analytics.devices (device_id, device_name, latitude, longitude, management_hostname, requested_metadata, requested_metrics) 
    VALUES 
        (1, 'Xochimilco-lan', 21.159425, -101.645852, '10.144.1.222' , '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]'),
        (2, 'Tlatelolco-lan', 21.159425, -101.645852, '10.144.1.1'   , '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]'),
        (3, 'Obsidian-lan'  , 21.159425, -101.645852, '10.144.1.225' , '["ansible_memory_mb", "ansible_fqdn", "ansible_kernel", "ansible_interfaces"]' , '[]');

SELECT * FROM Analytics.device_data_sources;
INSERT INTO Analytics.device_data_sources (device_id, fact_data_source)
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
UPDATE Analytics.devices SET requested_metrics = '["icmp_rtt"]';
UPDATE Analytics.devices SET metadata = NULL;

INSERT INTO Analytics.links (link_id, side_a, side_b, side_a_iface, side_b_iface, link_type)
    VALUES 
        (100, 1, 2, 'eth0', 'eth0', 'copper'),
        (101, 1, 3, 'eth0', 'eth0', 'copper'),
        (102, 2, 3, 'eth0', 'eth0', 'wireless');

SELECT * FROM Analytics.groups;
INSERT INTO Analytics.groups (group_id, group_name, is_display_group) 
    VALUES
        (201, 'Routers', 0<>0),
        (202, 'Hosts', 0<>1);
INSERT INTO Analytics.groups (group_id, group_name, is_display_group) 
    VALUES
        (203, 'Raíz', 0<>1);

UPDATE Analytics.groups SET is_display_group=0<>1 WHERE group_id = 202;

SELECT * FROM Analytics.group_members;
-- TRUNCATE Analytics.group_members;
INSERT INTO Analytics.group_members(group_id, item_id)
    VALUES
        (201, 1),
        (201, 2),
        (202, 3),
        (203, 201),
        (203, 202);
        -- Cyclic reference, the system should recognize it, and ignore it at the backend level
        --(201, 203); -- 203 parents 201, 201 parents 203. 201 will remove 203 from its children, or vice versa depending which gets evaluated first

--INSERT INTO Analytics.group_members(group_id, item_id)
--    VALUES

INSERT INTO Analytics.dashboard(dashboard_id, dashboard_name)
    VALUES
        (2, 'Dashboard 2'),
        (1, 'Default Dashboard');
SELECT dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition
            FROM Analytics.dashboard_items;

-- TRUNCATE Analytics.dashboard_items;
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (1, 0, 1, 0, 3, '{"start":"-1h", "aggregate-interval-s": 60, "update-interval-s": 60, "fields":["ansible_loadavg_15m", "baseline_1h_ansible_loadavg_15m"], "device-ids":1, "type": "metric", "chart-type":"line"}', '{}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (1, 1, 1, 0, 1, '{"update-interval-s": 60, "fields":["icmp_rtt"], "device-ids":1, "type":"metadata", "chart-type": "label"}', '{}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (1, 1, 1, 1, 1, '{"update-interval-s": 15, "fields":["icmp_status"], "device-ids":203, "type":"metadata", "chart-type": "pie"}', '{}');

INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (2, 1, 1, 0, 3, '{"start":"-1h", "aggregate-interval-s": 60, "update-interval-s": 60, "fields":["icmp_rtt"], "device-ids":1, "type": "metric", "chart-type":"line"}', '{}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (2, 0, 1, 0, 1, '{"update-interval-s": 60, "fields":["icmp_rtt"], "device-ids":1, "type":"metadata", "chart-type": "label"}', '{}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (2, 0, 1, 1, 1, '{"update-interval-s": 15, "fields":["icmp_status"], "device-ids":203, "type":"metadata", "chart-type": "pie"}', '{}');

-- TODO: Handle actual parent-child recursion
-- INSERT INTO Analytics.group_members(group_id, item_id) VALUES (203, 203);

-- TRUNCATE Analytics.alert_rules;

-- DELETE FROM Analytics.alerts; DELETE FROM Analytics.alert_rules;
INSERT INTO Analytics.alert_rules (rule_id, rule_name, requires_ack, rule_definition)
    VALUES  (1, 'ICMP_RTT > 100ms', TRUE, '{"severity":"warning","target":1,"reduce-logic": "all","data-source":"facts","rule-type": "simple", "predicates":[{"left-modifier": {"multi": {"operations": [{"add": -20.0}, {"mul": 1.2}]}}, "left":"&icmp_rtt","op":"more_than","right":60}]}'),
            (2, 'Syslog SSH', TRUE, '{"severity":"emergency","target":2,"reduce-logic": "any","data-source":"syslog","rule-type": "simple", "predicates":[{"left":"&syslog_message","op":"contains","right":"ssh"}, {"left":"&syslog_message","op":"contains","right":"login"}]}');

SELECT * FROM Analytics.alert_rules;

SELECT * FROM Analytics.alerts;
SELECT alert_id, alert_time, ack_time, requires_ack, severity, message, target_id, TRUE as ws_notified, TRUE as db_notified, (ack_actor <> NULL) as acked, rule_id, value FROM Analytics.alerts;
-- TRUNCATE Analytics.alerts;

SELECT count(1) AS count FROM Analytics.alerts OFFSET 0;

-- DROP TABLE Analytics.telegram_receiver;
-- TRUNCATE Analytics.telegram_receiver;
select * from Analytics.telegram_receiver;

SELECT * FROM Analytics.topology_views;
-- RUNCATE Analytics.topology_views;
INSERT INTO Analytics.topology_views(topology_views_id, is_physical_view, name)
    VALUES  (0, FALSE, 'Hasta la vista'),
            (1, FALSE, 'Baby'),
            (2, TRUE , 'Globbus');

-- DROP TABLE Analytics.topology_views_member;
-- TRUNCATE Analytics.topology_views_member;

SELECT * FROM Analytics.topology_views_member;
INSERT INTO Analytics.topology_views_member(topology_views_id, item_id, position_x, position_y)
    VALUES  (0, 1,  0.5,  0.5),
            (0, 2,  0.7, -0.2),
            (0, 3, -0.3 , 0.3), 

            (1, 1, -0.5 , 0.5),
            (1, 2,  0.7 , 0.5),
            --(1, 3, -0.3 , 0.3),

            (2, 201, 0, 0);

SET TIMEZONE TO 'America/Mexico_City';
-- TRUNCATE Syslog.system_events;
SELECT * FROM Syslog.system_events;
SELECT * FROM Syslog.system_events WHERE received_at BETWEEN '2025-10-27T06:00:00Z' AND '2025-11-11T21:13:45Z';


SELECT * FROM Telegram.receiver;

SELECT * FROM ClientIdentity.ack_tokens;
SELECT (telegram_user_id IS NULL) as empty FROM ClientIdentity.ack_tokens;
INSERT INTO ClientIdentity.ack_tokens(ack_token, ack_actor_name, can_ack) VALUES ('BE&d?bzhfvaXG12Upou3CtA-7|iHMk$QOnLNmJ6I0TerF94PD5lq#y:c8WsgK*jY', 'Héctor Ramírez Cano', TRUE);
INSERT INTO ClientIdentity.ack_tokens(ack_token, ack_actor_name, can_ack) VALUES ('I9tslevG&YfdVAB@Fogy#', 'Alt', FALSE);
SELECT (1) as exists FROM ClientIdentity.ack_tokens WHERE ack_token = 'BE&d?bzhfvaXG12Upou3CtA-7|iHMk$QOnLNmJ6I0TerF94PD5lq#y:c8WsgK*jY';

SELECT (telegram_user_id IS NULL OR telegram_user_id = 824918361) as valid FROM ClientIdentity.ack_tokens WHERE ack_token = 'I9tslevG&YfdVAB@Fogy#';

TRUNCATE Telegram.receiver;
TRUNCATE Telegram.unacked_messages;
SELECT * FROM Telegram.unacked_messages;
UPDATE ClientIdentity.ack_tokens SET telegram_user_id = NULL;

SELECT EXISTS(
            SELECT 1 FROM Telegram.receiver WHERE telegram_user_id = 0 AND authenticated is TRUE
        ) as authenticated