-- ============================================================
-- Migration 001 - Initial schema
-- smart-air: users, homes, devices, telemetry, commands, etc.
-- Run against: sa-postgres (timescale/timescaledb:latest-pg16)
-- ============================================================

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- ============================================================
-- USERS & AUTH
-- ============================================================

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR UNIQUE NOT NULL,
    password_hash   VARCHAR NOT NULL,
    full_name       VARCHAR,
    avatar_url      VARCHAR,
    phone           VARCHAR,
    is_verified     BOOLEAN DEFAULT false,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    token           VARCHAR UNIQUE NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- HOMES & ROOMS
-- ============================================================

CREATE TABLE homes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        UUID REFERENCES users(id),
    name            VARCHAR NOT NULL,
    address         VARCHAR,
    timezone        VARCHAR DEFAULT 'Asia/Ho_Chi_Minh',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE home_members (
    home_id         UUID REFERENCES homes(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    role            VARCHAR DEFAULT 'member', -- owner | admin | member
    PRIMARY KEY (home_id, user_id)
);

CREATE TABLE rooms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_id         UUID REFERENCES homes(id) ON DELETE CASCADE,
    name            VARCHAR NOT NULL,
    icon            VARCHAR
);

-- ============================================================
-- DEVICE TYPES
-- ============================================================

CREATE TABLE device_types (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR NOT NULL,        -- e.g. "smart_air_v1"
    display_name    VARCHAR,
    icon            VARCHAR,
    spec            JSONB NOT NULL
    -- spec example:
    -- {"properties":[{"key":"temperature","type":"float","unit":"°C"},
    --                {"key":"humidity","type":"float","unit":"%"}]}
);

-- ============================================================
-- DEVICES
-- ============================================================

CREATE TABLE devices (
    id              TEXT PRIMARY KEY,
    home_id         UUID REFERENCES homes(id),
    room_id         UUID REFERENCES rooms(id),
    type_id         UUID REFERENCES device_types(id),
    owner_id        UUID REFERENCES users(id),
    name            VARCHAR NOT NULL,
    secret_key      VARCHAR UNIQUE NOT NULL,  -- MQTT auth password (never logged)
    firmware_ver    VARCHAR,
    online          BOOLEAN DEFAULT false,
    last_seen       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DEVICE SHADOW (Redis primary, PostgreSQL backup)
-- ============================================================

CREATE TABLE device_shadows (
    device_id       TEXT PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    reported        JSONB DEFAULT '{}',  -- actual state from device
    desired         JSONB DEFAULT '{}',  -- target state from app
    updated_at      TIMESTAMPTZ DEFAULT NOW()
    -- delta = desired - reported (computed at query time, not stored)
);

-- ============================================================
-- COMMANDS
-- ============================================================

CREATE TABLE commands (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       TEXT REFERENCES devices(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),
    payload         JSONB NOT NULL,
    status          VARCHAR DEFAULT 'pending', -- pending -> sent -> done | error | timeout
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    executed_at     TIMESTAMPTZ
);

-- ============================================================
-- TELEMETRY (TimescaleDB hypertable - partitioned by time)
-- ============================================================

CREATE TABLE telemetry (
    device_id       TEXT NOT NULL,
    ts              TIMESTAMPTZ NOT NULL,
    payload         JSONB NOT NULL
    -- payload example: {"temperature":28.5,"humidity":65.2}
);

-- Convert to hypertable (partition by ts, 7-day chunks by default)
SELECT create_hypertable('telemetry', 'ts', if_not_exists => TRUE);

-- Auto-drop data older than 1 year
SELECT add_retention_policy('telemetry', INTERVAL '1 year', if_not_exists => TRUE);

-- ============================================================
-- AUTOMATIONS
-- ============================================================

CREATE TABLE automations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_id         UUID REFERENCES homes(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),
    name            VARCHAR NOT NULL,
    enabled         BOOLEAN DEFAULT true,
    trigger         JSONB NOT NULL,
    -- trigger examples:
    -- {"type":"telemetry","device_id":"…","property":"temperature","operator":">","value":30}
    -- {"type":"schedule","cron":"0 8 * * *"}
    action          JSONB NOT NULL,
    -- {"device_id":"…","command":{"power":false}}
    last_triggered  TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR NOT NULL,
    body            VARCHAR,
    type            VARCHAR,   -- alert | info | command_result
    read            BOOLEAN DEFAULT false,
    payload         JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE fcm_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    token           VARCHAR NOT NULL,
    platform        VARCHAR,   -- ios | android
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SEED DATA - device_types
-- ============================================================

INSERT INTO device_types (name, display_name, icon, spec) VALUES (
    'smart_air_v1',
    'Smart Air v1',
    'air_quality',
    '{
        "properties": [
            {"key": "temperature", "type": "float",   "unit": "°C",  "label": "Nhiệt độ"},
            {"key": "humidity",    "type": "float",   "unit": "%",   "label": "Độ ẩm"},
            {"key": "timestamp",   "type": "integer", "unit": "unix","label": "Thời gian"}
        ],
        "controls": [
            {"key": "power", "type": "bool", "label": "Nguồn"}
        ]
    }'
);

-- ============================================================
-- INDEXES (performance for common queries)
-- ============================================================

-- Telemetry: query by device + time range (most common access pattern)
CREATE INDEX ON telemetry (device_id, ts DESC);

-- Commands: filter by device + status
CREATE INDEX ON commands (device_id, status, created_at DESC);

-- Notifications: filter by user + unread
CREATE INDEX ON notifications (user_id, read, created_at DESC);

-- refresh_tokens: lookup by token value
CREATE INDEX ON refresh_tokens (token);
