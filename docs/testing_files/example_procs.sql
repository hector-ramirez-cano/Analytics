--    $$$$$$$\                      $$\       $$\                                           $$\
--    $$  __$$\                     $$ |      $$ |                                          $$ |
--    $$ |  $$ | $$$$$$\   $$$$$$$\ $$$$$$$\  $$$$$$$\   $$$$$$\   $$$$$$\   $$$$$$\   $$$$$$$ | $$$$$$$\
--    $$ |  $$ | \____$$\ $$  _____|$$  __$$\ $$  __$$\ $$  __$$\  \____$$\ $$  __$$\ $$  __$$ |$$  _____|
--    $$ |  $$ | $$$$$$$ |\$$$$$$\  $$ |  $$ |$$ |  $$ |$$ /  $$ | $$$$$$$ |$$ |  \__|$$ /  $$ |\$$$$$$\
--    $$ |  $$ |$$  __$$ | \____$$\ $$ |  $$ |$$ |  $$ |$$ |  $$ |$$  __$$ |$$ |      $$ |  $$ | \____$$\
--    $$$$$$$  |\$$$$$$$ |$$$$$$$  |$$ |  $$ |$$$$$$$  |\$$$$$$  |\$$$$$$$ |$$ |      \$$$$$$$ |$$$$$$$  |
--    \_______/  \_______|\_______/ \__|  \__|\_______/  \______/  \_______|\__|       \_______|\_______/
INSERT INTO Analytics.dashboard(dashboard_id, dashboard_name)
    VALUES
        (2, 'Dashboard 2'),
        (1, 'Default Dashboard');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (1, 0, 1, 0, 3, '{"start":"-1h", "aggregate-interval-s": 60, "update-interval-s": 60, "fields":["ansible_loadavg_15m", "baseline_1h_ansible_loadavg_15m"], "device-ids":1, "type": "metric", "chart-type":"line"}',
        '{}'
        );
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (1, 1, 1, 0, 1, '{"update-interval-s": 60, "fields":["icmp_rtt"], "device-ids":1, "type":"metadata", "chart-type": "label"}', '{}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (1, 1, 1, 1, 1, '{"update-interval-s": 15, "fields":["icmp_status"], "device-ids":203, "type":"metadata", "chart-type": "pie"}',
        '{"pie-colors": ["ffdcd6f7", "ffa6b1e1", "ffb4869f", "ff985f6f", "ff4e4c67"], "text-colors": ["FF000000", "FF000000", "FF000000", "FFFFFFFF", "FFFFFFFF", "FFFFFFFF", "FFFFFFFF"]}');

INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (2, 1, 1, 0, 3, '{"start":"-1h", "aggregate-interval-s": 60, "update-interval-s": 60, "fields":["icmp_rtt"], "device-ids":1, "type": "metric", "chart-type":"line"}',
        '{
            "line-colors": ["FF321325", "FF5f0f40", "FF9a031e", "FFcb793a", "FFfcdc4d"]
        }');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (2, 0, 1, 0, 1, '{"update-interval-s": 60, "fields":["icmp_rtt"], "device-ids":1, "type":"metadata", "chart-type": "label"}', '{}');
INSERT INTO Analytics.dashboard_items(dashboard_id, row_start, row_span, col_start, col_span, polling_definition, style_definition)
    VALUES
        (2, 0, 1, 1, 1, '{"update-interval-s": 15, "fields":["icmp_status"], "device-ids":203, "type":"metadata", "chart-type": "pie"}', '{}');


--    $$$$$$$$\                            $$\                                     $$\    $$\ $$\
--    \__$$  __|                           $$ |                                    $$ |   $$ |\__|
--       $$ | $$$$$$\   $$$$$$\   $$$$$$\  $$ | $$$$$$\   $$$$$$\  $$\   $$\       $$ |   $$ |$$\  $$$$$$\  $$\  $$\  $$\  $$$$$$$\
--       $$ |$$  __$$\ $$  __$$\ $$  __$$\ $$ |$$  __$$\ $$  __$$\ $$ |  $$ |      \$$\  $$  |$$ |$$  __$$\ $$ | $$ | $$ |$$  _____|
--       $$ |$$ /  $$ |$$ /  $$ |$$ /  $$ |$$ |$$ /  $$ |$$ /  $$ |$$ |  $$ |       \$$\$$  / $$ |$$$$$$$$ |$$ | $$ | $$ |\$$$$$$\
--       $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |        \$$$  /  $$ |$$   ____|$$ | $$ | $$ | \____$$\
--       $$ |\$$$$$$  |$$$$$$$  |\$$$$$$  |$$ |\$$$$$$  |\$$$$$$$ |\$$$$$$$ |         \$  /   $$ |\$$$$$$$\ \$$$$$\$$$$  |$$$$$$$  |
--       \__| \______/ $$  ____/  \______/ \__| \______/  \____$$ | \____$$ |          \_/    \__| \_______| \_____\____/ \_______/
--                     $$ |                              $$\   $$ |$$\   $$ |
--                     $$ |                              \$$$$$$  |\$$$$$$  |
--                     \__|                               \______/  \______/

INSERT INTO Analytics.topology_views(topology_views_id, name)
    VALUES  (0, 'Hasta la vista'),
            (1, 'Baby');

INSERT INTO Analytics.topology_views_member(topology_views_id, item_id, position_x, position_y)
    VALUES  (0, 1,  0.5,  0.5),
            (0, 2,  0.7, -0.2),
            (0, 3, -0.3 , 0.3), 

            (1, 1, -0.5 , 0.5),
            (1, 2,  0.7 , 0.5);


--    $$$$$$$$\        $$\                                                      
--    \__$$  __|       $$ |                                                     
--       $$ | $$$$$$\  $$ | $$$$$$\   $$$$$$\   $$$$$$\  $$$$$$\  $$$$$$\$$$$\  
--       $$ |$$  __$$\ $$ |$$  __$$\ $$  __$$\ $$  __$$\ \____$$\ $$  _$$  _$$\ 
--       $$ |$$$$$$$$ |$$ |$$$$$$$$ |$$ /  $$ |$$ |  \__|$$$$$$$ |$$ / $$ / $$ |
--       $$ |$$   ____|$$ |$$   ____|$$ |  $$ |$$ |     $$  __$$ |$$ | $$ | $$ |
--       $$ |\$$$$$$$\ $$ |\$$$$$$$\ \$$$$$$$ |$$ |     \$$$$$$$ |$$ | $$ | $$ |
--       \__| \_______|\__| \_______| \____$$ |\__|      \_______|\__| \__| \__|
--                                   $$\   $$ |                                 
--                                   \$$$$$$  |                                 
--                                    \______/                                  
INSERT INTO ClientIdentity.ack_tokens(ack_token, ack_actor_name, can_ack) VALUES ('BE&d?bzhfvaXG12Upou3C', 'Supervisor', TRUE);
INSERT INTO ClientIdentity.ack_tokens(ack_token, ack_actor_name, can_ack) VALUES ('I9tslevG&YfdVAB@Fogy#', 'Analista', FALSE);
