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
    name              VARCHAR(254) NOT NULL
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

CREATE TABLE IF NOT EXISTS Analytics.alert_rules (
    rule_id         BIGSERIAL PRIMARY KEY,
    rule_name       VARCHAR(254) NOT NULL,
    requires_ack    BOOLEAN NOT NULL,
    rule_definition JSONB NOT NULL
);

CREATE TYPE AlertSeverity AS ENUM ('emergency','alert','critical','error','warning','notice','info','debug','unknown');
CREATE TABLE IF NOT EXISTS Analytics.alerts (
    alert_id     BIGSERIAL PRIMARY KEY,
    alert_time   TIMESTAMPTZ NOT NULL,
    ack_time     TIMESTAMPTZ,
    requires_ack BOOLEAN NOT NULL,
    severity     AlertSeverity NOT NULL DEFAULT 'unknown',
    message      VARCHAR(254),
    ack_actor    VARCHAR(254),
    target_id    BIGINT,
    value        VARCHAR(254) NOT NULL,
    rule_id      BIGINT,

    FOREIGN KEY (target_id) REFERENCES Analytics.devices(device_id) ON DELETE CASCADE,
    FOREIGN KEY (rule_id) REFERENCES Analytics.alert_rules(rule_id)
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

CREATE TABLE IF NOT EXISTS Analytics.dashboard(
    dashboard_id BIGSERIAL PRIMARY KEY,
    dashboard_name VARCHAR(254) NOT NULL
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

CREATE SCHEMA IF NOT EXISTS Syslog;

-- DROP TABLE Syslog.system_events; DROP TYPE SyslogSeverity; DROP TYPE SyslogFacility;

CREATE TYPE SyslogSeverity as enum('emerg','alert','crit','err','warning','notice','info','debug');
CREATE TYPE SyslogFacility as enum('kern','user','mail','daemon','auth','syslog','lpr','news','uucp','cron','authpriv','ftp','ntp','security','console','solaris','local0','local1','local2','local3','local4','local5','local6','local7');
CREATE TABLE IF NOT EXISTS Syslog.system_events  (
    id BIGSERIAL PRIMARY KEY,
    facility SyslogFacility NOT NULL,
    severity SyslogSeverity NOT NULL,
    from_host TEXT,
    received_at TIMESTAMPTZ,
    process_id TEXT,
    message TEXT,
    
    -- Not displayed, but stored for reference
    message_id TEXT,
    appname TEXT,

    message_tsv tsvector GENERATED ALWAYS AS (to_tsvector('english', message)) STORED
);
-- FTS Search index
CREATE INDEX idx_SystemEvents_Message_tsv ON Syslog.system_events USING GIN (message_tsv);

-- Indices
CREATE INDEX idx_SystemEvents_FromHost ON Syslog.system_events (from_host);
CREATE INDEX idx_SystemEvents_ReceivedAt ON Syslog.system_events (received_at);

--  ______        __                        __      __    __               
-- /      |      /  |                      /  |    /  |  /  |              
-- $$$$$$/   ____$$ |  ______   _______   _$$ |_   $$/  _$$ |_    __    __ 
--   $$ |   /    $$ | /      \ /       \ / $$   |  /  |/ $$   |  /  |  /  |
--   $$ |  /$$$$$$$ |/$$$$$$  |$$$$$$$  |$$$$$$/   $$ |$$$$$$/   $$ |  $$ |
--   $$ |  $$ |  $$ |$$    $$ |$$ |  $$ |  $$ | __ $$ |  $$ | __ $$ |  $$ |
--  _$$ |_ $$ \__$$ |$$$$$$$$/ $$ |  $$ |  $$ |/  |$$ |  $$ |/  |$$ \__$$ |
-- / $$   |$$    $$ |$$       |$$ |  $$ |  $$  $$/ $$ |  $$  $$/ $$    $$ |
-- $$$$$$/  $$$$$$$/  $$$$$$$/ $$/   $$/    $$$$/  $$/    $$$$/   $$$$$$$ |
--                                                               /  \__$$ |
--                                                               $$    $$/ 
--                                                                $$$$$$/  
CREATE SCHEMA IF NOT EXISTS ClientIdentity;
CREATE TABLE IF NOT EXISTS ClientIdentity.ack_tokens(
    ack_token VARCHAR(128) PRIMARY KEY,
    ack_actor_name VARCHAR NOT NULL,
    can_ack BOOLEAN NOT NULL,

    telegram_user_id BIGINT -- managed by telegram, trusted to be unique
);


CREATE SCHEMA IF NOT EXISTS Telegram;

CREATE TABLE IF NOT EXISTS Telegram.receiver(
    telegram_chat_id BIGINT PRIMARY KEY, --managed by telegram, trusted to be unique
    authenticated    BOOLEAN NOT NULL,
    subscribed       BOOLEAN NOT NULL,

    ack_token        VARCHAR(128),

    FOREIGN KEY(ack_token) REFERENCES ClientIdentity.ack_tokens ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS Telegram.unacked_messages(
    alert_id BIGINT NOT NULL,
    chat_peer_id   BIGINT NOT NULL,
    message_id     BIGINT NOT NULL,

    FOREIGN KEY(alert_id) REFERENCES Analytics.alerts ON DELETE CASCADE
);