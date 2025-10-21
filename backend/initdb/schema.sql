CREATE SCHEMA IF NOT EXISTS Analytics;

CREATE TYPE ItemType AS ENUM ('device', 'link', 'group');
CREATE TYPE LinkType AS ENUM ('optical', 'copper', 'wireless');
CREATE TYPE DataSource AS ENUM('ssh', 'snmp', 'icmp');

CREATE TABLE IF NOT EXISTS Analytics.items (
    id SERIAL PRIMARY KEY,
    item_type ItemType NOT NULL
);

CREATE TABLE IF NOT EXISTS Analytics.devices (
    device_id           SERIAL PRIMARY KEY,
    device_name         VARCHAR(254),
    position_x          FLOAT        NOT NULL,
    position_y          FLOAT        NOT NULL,
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


CREATE TABLE IF NOT EXISTS Analytics.device_data_sources(
    device_id           SERIAL     NOT NULL,
    data_source         DataSource NOT NULL,

    FOREIGN KEY (device_id) REFERENCES Analytics.devices(device_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Analytics.links (
    link_id   SERIAL PRIMARY KEY,
    side_a    INT NOT NULL,
    side_b    INT NOT NULL,
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
    alert_id     SERIAL,
    alert_time   TIMESTAMP NOT NULL,
    ack_time     TIMESTAMP,
    requires_ack BOOLEAN NOT NULL,
    severity     AlertSeverity NOT NULL,
    message      VARCHAR,
    ack_actor    VARCHAR,
    target_id    INT,

    FOREIGN KEY (target_id) REFERENCES Analytics.devices(device_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Analytics.alert_rules (
    rule_id         SERIAL PRIMARY KEY,
    rule_name       VARCHAR(128),
    requires_ack    BOOLEAN NOT NULL,
    rule_definition JSONB
);

CREATE TABLE IF NOT EXISTS Analytics.groups (
    group_id SERIAL PRIMARY KEY,
    group_name VARCHAR(254) NOT NULL,
    is_display_group BOOLEAN NOT NULL,

    FOREIGN KEY (group_id) REFERENCES Analytics.items(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Analytics.group_members (
    group_id INT NOT NULL,
    item_id INT NOT NULL,

    FOREIGN KEY (group_id) REFERENCES Analytics.groups(group_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES Analytics.items(id) ON DELETE CASCADE,

    CONSTRAINT chk_group_no_recurse CHECK (group_id <> item_id)
);

CREATE TABLE IF NOT EXISTS Analytics.dashboard(
    dashboard_id SERIAL PRIMARY KEY,
    dashboard_name VARCHAR NOT NULL
);

DROP TABLE Analytics.dashboard_items;

CREATE TABLE IF NOT EXISTS Analytics.dashboard_items(
    dashboard_id INT NOT NULL,
    row_start    INT NOT NULL,
    row_span     INT NOT NULL,
    col_start    INT NOT NULL,
    col_span     INT NOT NULL,
    is_metric    BOOLEAN NOT NULL,
    field        VARCHAR NOT NULL,

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
