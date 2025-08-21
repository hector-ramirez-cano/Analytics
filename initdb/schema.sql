CREATE SCHEMA IF NOT EXISTS Analytics;

CREATE TYPE ItemType AS ENUM ('device', 'link', 'group');
CREATE TYPE LinkType AS ENUM ('optical', 'copper', 'wireless');

CREATE TABLE IF NOT EXISTS Analytics.items (
    id SERIAL PRIMARY KEY,
    item_type ItemType NOT NULL
);

CREATE TABLE IF NOT EXISTS Analytics.devices (
    device_id   INT PRIMARY KEY,
    device_name VARCHAR(254),
    position_x  FLOAT NOT NULL,
    position_y  FLOAT NOT NULL,
    management_hostname varchar(254) NOT NULL,
    FOREIGN KEY (device_id) REFERENCES Analytics.items(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Analytics.links (
    link_id   INT PRIMARY KEY,
    side_a    INT NOT NULL,
    side_b    INT NOT NULL,
    link_type LinkType NOT NULL,
    link_subtype VARCHAR(254),

    FOREIGN KEY (link_id) REFERENCES Analytics.items(id) ON DELETE CASCADE,
    FOREIGN KEY (side_a) REFERENCES Analytics.devices(device_id),
    FOREIGN KEY (side_b) REFERENCES Analytics.devices(device_id),

    CONSTRAINT chk_link_sides_different CHECK (side_a <> side_b)
);

-- enforce uniqueness of link pairs regardless of order
CREATE UNIQUE INDEX IF NOT EXISTS uniq_link_pair
ON Analytics.links (LEAST(side_a, side_b), GREATEST(side_a, side_b));

CREATE TABLE IF NOT EXISTS Analytics.groups (
    group_id INT PRIMARY KEY,
    group_name VARCHAR(254) NOT NULL,
    is_display_group BOOLEAN NOT NULL,

    FOREIGN KEY (group_id) REFERENCES Analytics.items(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Analytics.group_members (
    group_id INT NOT NULL,
    device_id INT NOT NULL,

    FOREIGN KEY (group_id) REFERENCES Analytics.groups(group_id),
    FOREIGN KEY (device_id) REFERENCES Analytics.devices(device_id)
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
