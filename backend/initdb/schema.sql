CREATE SCHEMA IF NOT EXISTS Analytics;
--   ______                       __              __      __                     
--  /      \                     /  |            /  |    /  |                    
-- /$$$$$$  | _______    ______  $$ | __    __  _$$ |_   $$/   _______   _______ 
-- $$ |__$$ |/       \  /      \ $$ |/  |  /  |/ $$   |  /  | /       | /       |
-- $$    $$ |$$$$$$$  | $$$$$$  |$$ |$$ |  $$ |$$$$$$/   $$ |/$$$$$$$/ /$$$$$$$/ 
-- $$$$$$$$ |$$ |  $$ | /    $$ |$$ |$$ |  $$ |  $$ | __ $$ |$$ |      $$      \ 
-- $$ |  $$ |$$ |  $$ |/$$$$$$$ |$$ |$$ \__$$ |  $$ |/  |$$ |$$ \_____  $$$$$$  |
-- $$ |  $$ |$$ |  $$ |$$    $$ |$$ |$$    $$ |  $$  $$/ $$ |$$       |/     $$/ 
-- $$/   $$/ $$/   $$/  $$$$$$$/ $$/  $$$$$$$ |   $$$$/  $$/  $$$$$$$/ $$$$$$$/  
--                                   /  \__$$ |                                  
--                                   $$    $$/                                   
--                                    $$$$$$/                                    

-- Custom function to validate ID is device or group
CREATE OR REPLACE FUNCTION validate_item_id(item_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM Analytics.devices WHERE device_id = item_id)
        OR EXISTS (SELECT 1 FROM Analytics.groups WHERE group_id = item_id);
END;
$$ LANGUAGE plpgsql;

CREATE TYPE ItemType AS ENUM ('device', 'link', 'group');
CREATE TYPE LinkType AS ENUM ('optical', 'copper', 'wireless', 'unknown');
CREATE TYPE DataSource AS ENUM('ssh', 'snmp', 'icmp');

CREATE SEQUENCE global_item_id_seq;
CREATE TABLE IF NOT EXISTS Analytics.items (
    id BIGSERIAL PRIMARY KEY,
    item_type ItemType NOT NULL
);

CREATE TABLE IF NOT EXISTS Analytics.devices (
    device_id           BIGINT PRIMARY KEY DEFAULT nextval('global_item_id_seq'),
    device_name         VARCHAR(254),
    latitude            FLOAT        NOT NULL,
    longitude           FLOAT        NOT NULL,
    management_hostname VARCHAR(254) NOT NULL,
    metadata            JSONB,

    requested_metadata  JSONB        NOT NULL,
    requested_metrics   JSONB        NOT NULL,
    available_values    JSONB,
    
    snmp_configuration  JSONB,

    FOREIGN KEY (device_id) REFERENCES Analytics.items(id) ON DELETE CASCADE,

    CONSTRAINT chk_lat_in_range CHECK (latitude >= -90.0 AND latitude <= 90),
    CONSTRAINT chk_lng_in_range CHECK (longitude >= -180 AND longitude <= 180)
);

CREATE TABLE IF NOT EXISTS Analytics.topology_views(
    topology_views_id BIGSERIAL PRIMARY KEY,
    is_physical_view  BOOLEAN NOT NULL,
    name              VARCHAR NOT NULL
);

-- DROP TABLE Analytics.topology_views_member;
CREATE TABLE IF NOT EXISTS Analytics.topology_views_member(
    topology_views_id BIGINT NOT NULL,
    item_id           BIGINT NOT NULL,
    position_x        FLOAT DEFAULT 0.0,
    position_y        FLOAT DEFAULT 0.0,

    FOREIGN KEY (topology_views_id) REFERENCES Analytics.topology_views ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES Analytics.items ON DELETE CASCADE,

    CONSTRAINT chk_topology_view_members CHECK (validate_item_id(item_id)),
    CONSTRAINT unique_topology_item_pair UNIQUE (topology_views_id, item_id)
);

CREATE TABLE IF NOT EXISTS Analytics.device_data_sources(
    device_id    BIGINT        NOT NULL,
    fact_data_source  DataSource NOT NULL,

    FOREIGN KEY (device_id) REFERENCES Analytics.devices(device_id) ON DELETE CASCADE,
    CONSTRAINT unique_device_data_source_pair UNIQUE (device_id, fact_data_source)
);

CREATE TABLE IF NOT EXISTS Analytics.links (
    link_id   BIGINT PRIMARY KEY DEFAULT nextval('global_item_id_seq'),
    side_a    BIGINT NOT NULL,
    side_b    BIGINT NOT NULL,
    side_a_iface VARCHAR(254) NOT NULL,
    side_b_iface VARCHAR(254) NOT NULL,
    link_type LinkType NOT NULL,
    link_subtype VARCHAR(254),

    FOREIGN KEY (link_id) REFERENCES Analytics.items(id) ON DELETE CASCADE,
    FOREIGN KEY (side_a) REFERENCES Analytics.devices(device_id) ON DELETE CASCADE,
    FOREIGN KEY (side_b) REFERENCES Analytics.devices(device_id) ON DELETE CASCADE,

    CONSTRAINT chk_link_sides_different CHECK (side_a <> side_b)
);

-- enforce uniqueness of link pairs regardless of order
CREATE UNIQUE INDEX IF NOT EXISTS unique_link_pair
ON Analytics.links (LEAST(side_a, side_b), GREATEST(side_a, side_b));


CREATE TYPE AlertSeverity AS ENUM('emergency', 'alert', 'critical', 'error', 'warning', 'notice', 'info', 'debug');
CREATE TABLE IF NOT EXISTS Analytics.alerts (
    alert_id     BIGSERIAL,
    alert_time   TIMESTAMP NOT NULL,
    ack_time     TIMESTAMP,
    requires_ack BOOLEAN NOT NULL,
    severity     AlertSeverity NOT NULL,
    message      VARCHAR,
    ack_actor    VARCHAR,
    target_id    BIGINT,
    value        VARCHAR NOT NULL,

    FOREIGN KEY (target_id) REFERENCES Analytics.devices(device_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Analytics.alert_rules (
    rule_id         BIGSERIAL PRIMARY KEY,
    rule_name       VARCHAR(128),
    requires_ack    BOOLEAN NOT NULL,
    rule_definition JSONB
);

CREATE TABLE IF NOT EXISTS Analytics.groups (
    group_id         BIGINT PRIMARY KEY DEFAULT nextval('global_item_id_seq'),
    group_name       VARCHAR(254) NOT NULL,
    is_display_group BOOLEAN NOT NULL,

    FOREIGN KEY (group_id) REFERENCES Analytics.items(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Analytics.group_members (
    group_id BIGINT NOT NULL,
    item_id  BIGINT NOT NULL,

    FOREIGN KEY (group_id) REFERENCES Analytics.groups(group_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES Analytics.items(id) ON DELETE CASCADE,

    CONSTRAINT chk_group_no_recurse CHECK (group_id <> item_id),
    CONSTRAINT unique_group_item_pair UNIQUE (group_id, item_id)
);

SELECT g.group_id, g.group_name as name, g.is_display_group, array_agg(gm.item_id) FROM Analytics.groups as g JOIN Analytics.group_members gm on gm.group_id = g.group_id GROUP BY g.group_id, g.group_name;

CREATE TABLE IF NOT EXISTS Analytics.dashboard(
    dashboard_id BIGSERIAL PRIMARY KEY,
    dashboard_name VARCHAR NOT NULL
);

-- DROP TABLE Analytics.dashboard_items;

CREATE TABLE IF NOT EXISTS Analytics.dashboard_items(
    dashboard_id SMALLINT NOT NULL,
    row_start    SMALLINT NOT NULL,
    row_span     SMALLINT NOT NULL,
    col_start    SMALLINT NOT NULL,
    col_span     SMALLINT NOT NULL,
    style_definition    JSONB NOT NULL DEFAULT '{}',
    polling_definition JSONB NOT NULL,

    FOREIGN KEY (dashboard_id) REFERENCES Analytics.dashboard (dashboard_id) ON DELETE CASCADE,

    CONSTRAINT chk_row_pos  CHECK (row_start >= 0),
    CONSTRAINT chk_col_pos  CHECK (col_start >= 0),
    CONSTRAINT chk_row_span CHECK (row_span  >= 1),
    CONSTRAINT chk_col_span CHECK (col_span  >= 1)
);


CREATE TABLE IF NOT EXISTS Analytics.telegram_receiver(
    telegram_user_id NUMERIC (32, 0) PRIMARY KEY, --managed by telegram, trusted to be unique
    authenticated    BOOLEAN NOT NULL,
    subscribed       BOOLEAN NOT NULL
);

-- Trigger functions
CREATE OR REPLACE FUNCTION create_item_on_device_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Analytics.items (id, item_type)
    VALUES (NEW.device_id, 'device')
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_item_on_link_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Analytics.items (id, item_type)
    VALUES (NEW.link_id, 'link')
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_item_on_group_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Analytics.items (id, item_type)
    VALUES (NEW.group_id, 'group')
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
CREATE TRIGGER tgr_create_device
BEFORE INSERT ON Analytics.devices
FOR EACH ROW
EXECUTE FUNCTION create_item_on_device_insert();

CREATE TRIGGER tgr_create_link
BEFORE INSERT ON Analytics.links
FOR EACH ROW
EXECUTE FUNCTION create_item_on_link_insert();

CREATE TRIGGER tgr_create_group
BEFORE INSERT ON Analytics.groups
FOR EACH ROW
EXECUTE FUNCTION create_item_on_group_insert();



--   ______                       __                     
--  /      \                     /  |                    
-- /$$$$$$  | __    __   _______ $$ |  ______    ______  
-- $$ \__$$/ /  |  /  | /       |$$ | /      \  /      \ 
-- $$      \ $$ |  $$ |/$$$$$$$/ $$ |/$$$$$$  |/$$$$$$  |
--  $$$$$$  |$$ |  $$ |$$      \ $$ |$$ |  $$ |$$ |  $$ |
-- /  \__$$ |$$ \__$$ | $$$$$$  |$$ |$$ \__$$ |$$ \__$$ |
-- $$    $$/ $$    $$ |/     $$/ $$ |$$    $$/ $$    $$ |
--  $$$$$$/   $$$$$$$ |$$$$$$$/  $$/  $$$$$$/   $$$$$$$ |
--           /  \__$$ |                        /  \__$$ |
--           $$    $$/                         $$    $$/ 
--            $$$$$$/                           $$$$$$/  

DROP SCHEMA Syslog;
CREATE SCHEMA IF NOT EXISTS Syslog;

-- DROP TABLE Syslog.system_events;
CREATE TABLE IF NOT EXISTS Syslog.system_events (
    id BIGSERIAL PRIMARY KEY,
    facility SMALLINT,
    priority SMALLINT,
    from_host TEXT,
    info_unit_id INTEGER,
    received_at TIMESTAMPTZ,
    syslog_tag TEXT,
    process_id TEXT,
    message TEXT,
    message_tsv tsvector GENERATED ALWAYS AS (to_tsvector('english', message)) STORED
);
-- FTS Search index
CREATE INDEX idx_SystemEvents_Message_tsv ON Syslog.system_events USING GIN (message_tsv);

-- Indices
CREATE INDEX idx_SystemEvents_FromHost ON Syslog.system_events (from_host);
CREATE INDEX idx_SystemEvents_ReceivedAt ON Syslog.system_events (received_at);
