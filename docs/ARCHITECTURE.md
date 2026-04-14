# ARCHITECTURE.md — smart-air System Architecture

> Canonical system architecture reference — covers all 6 layers: hardware, firmware, cloud, database, API, mobile app.
> Update this file whenever a new subsystem is added or a component boundary changes.
> Agent: read this file before making any structural or cross-layer changes.

---

## System Overview

**smart-air** là thiết bị giám sát chất lượng không khí trong nhà và điều khiển thiết bị thông minh.
Stack: ESP32-S3 (ESP-IDF v5.x) + Flutter app (iOS/Android) + self-hosted IoT cloud (Raspberry Pi → VPS).

```
╔═════════════════════════════════════════════════════════════╗
║                        INTERNET                             ║
║                                                             ║
║   [Flutter App]    [Web Admin]      [ESP32 ở nhà user]      ║
║        │               │                   │                ║
║        │ HTTPS/REST    │ HTTPS             │ MQTT TLS       ║
║        │ MQTT/WSS      │                   │ :8883          ║
╚════════╪═══════════════╪═══════════════════╪════════════════╝
         │               │                   │
    [Cloudflare Tunnel / Domain]             │
         │               │                   │
╔════════▼═══════════════▼═══════════════════▼════════════════╗
║            Cloud Server (Raspberry Pi 4 → VPS)              ║
║                                                             ║
║  ┌──────────────────────────────────────────────────────┐   ║
║  │                     Nginx                            │   ║
║  │   /api/*   /ws   /grafana   :8883(MQTT TLS)          │   ║
║  └───┬─────────┬──────────────┬─────────────────────────┘   ║
║      │         │              │                             ║
║  ┌───▼───┐ ┌───▼───┐    ┌─────▼──────┐  ┌──────────────┐    ║
║  │Node.js│ │ EMQX  │    │  Grafana   │  │   pgAdmin    │    ║
║  │Fastify│ │Broker │    │ (telemetry)│  │  Portainer   │    ║
║  └───┬───┘ └───┬───┘    └────────────┘  └──────────────┘    ║
║      │         │                                            ║
║  ┌───▼─────────▼──────────────────────────┐                 ║
║  │              Redis 7                   │                 ║
║  │  • Device Shadow   • JWT Session       │                 ║
║  │  • Command Queue   • Rate Limiting     │                 ║
║  └───────────────────┬────────────────────┘                 ║
║                      │                                      ║
║  ┌───────────────────▼────────────────────┐                 ║
║  │     PostgreSQL 15 + TimescaleDB        │                 ║
║  └────────────────────────────────────────┘                 ║
╚═════════════════════════════════════════════════════════════╝
                         │ MQTT TLS :8883
┌────────────────────────▼────────────────────────────────────┐
│                  ESP32-S3 Firmware (ESP-IDF v5.x)           │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  ┌────────┐   │
│  │  Sensors │  │ Display  │  │   Network    │  │  Core  │   │
│  │  SHT3x   │  │  ST7789  │  │  WiFi STA    │  │  NVS   │   │
│  │  DS3231  │  │  XPT2046 │  │  MQTT TLS    │  │  OTA   │   │
│  └────┬─────┘  └────┬─────┘  │  HTTP/mDNS   │  │  BLE   │   │
│       │I2C          │SPI     │  DNS         │  └────────┘   │
│       │             │        └──────────────┘               │
└───────┴─────────────┴───────────────────────────────────────┘
                         │ SDIO / SPI
┌────────────────────────▼────────────────────────────────────┐
│                   Custom KiCad PCB Hardware                 │
│   ESP32-S3 MCU · 5V→3.3V regulator · sensors · SD card      │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer 1 — Hardware (`hardware/`)

Custom PCB thiết kế bằng KiCad v8.
Schematic gốc: `hardware/smart-air/smart-air.kicad_sch`.
Thư viện linh kiện: `hardware/lib/` (mỗi module là 1 sub-project).

| Subsystem    | Component        | Interface  | Notes                                  |
| ------------ | ---------------- | ---------- | -------------------------------------- |
| Sensor — T/H | SHT3x            | I2C        | 0x44 (ADDR pin low), 400 kHz           |
| Sensor — RTC | DS3231           | I2C        | 0x68, 400 kHz                          |
| Display      | ST7789 (TFT LCD) | SPI        | SPI2_HOST, 10 MHz, CPOL=0 CPHA=0       |
| Touch        | XPT2046          | SPI        | SPI2_HOST, 2 MHz max (slow dev handle) |
| Storage      | SD card          | SDIO / SPI | SDIO preferred (4-bit); SPI fallback   |
| I/O          | Buzzer           | LEDC/GPIO  | PWM via LEDC for tone control          |
| I/O          | LEDs             | GPIO/LEDC  | PWM for dimming                        |
| Power        | 5V → 3.3V reg    | —          | See `hardware/` KiCad schematic        |

### SD card — SDIO vs SPI

SDIO (4-bit) là interface ưu tiên: throughput cao hơn đáng kể, dùng SDMMC peripheral chuyên dụng, cần pin riêng (không chia sẻ SPI2_HOST). Fallback sang SPI bus riêng nếu pin constraints bắt buộc.

```
SDIO (preferred)            SPI (fallback)
SDMMC peripheral            Separate SPI bus — NOT SPI2_HOST
CLK / CMD / D0–D3           CLK / MOSI / MISO / CS
```

---

## Layer 2 — Firmware (`firmware/`)

ESP-IDF v5.x + FreeRTOS. Entry point: `firmware/main/main.c` → `void app_main(void)` → `systemLaunch()`.

### Boot Sequence

```
app_main()
  └── systemLaunch()
        ├── nvs_init()              — init NVS flash
        ├── i2c_bus_init()          — shared I2C master (400 kHz)
        ├── spi_bus_init()          — shared SPI2_HOST
        ├── driver_init_all()       — SHT3x, DS3231, ST7789, XPT2046
        ├── sdmmc_init()            — SD card (SDIO 4-bit mode)
        ├── ble_prov_start()        — BLE advertising (if not provisioned)
        │     └── on creds received:
        │           ├── wifi_sta_connect(ssid, pass)
        │           ├── nvs_save_credentials()
        │           └── ble_prov_stop()
        ├── wifi_connect()          — connect using saved NVS credentials
        ├── mqtt_start()            — connect broker TLS, sub/pub topics
        ├── webserver_start()       — HTTP config server + mDNS
        └── tasks_start_all()       — sensor, display, mqtt, sd_log tasks
```

### BLE Provisioning Flow

```
Phone                    BLE (GATT)             prov_task           WiFi / NVS
  │                          │                      │                     │
  │── scan / discover ──────→│                      │                     │
  │←── ADV_IND (prov UUID) ──│                      │                     │
  │── GATT connect ─────────→│                      │                     │
  │── subscribe 0xFF03 ─────→│                      │                     │
  │── Write 0xFF01 (SSID) ──→│── s_got_ssid ───────→│                     │
  │── Write 0xFF02 (Pass) ──→│── xTaskNotifyGive ──→│                     │
  │                          │                      ├── wifi_connect() ──→│
  │                          │                      │←── IP_EVENT_GOT_IP ─│
  │                          │                      ├── nvs_save() ──────→│
  │                          │←── notify (JSON) ────│                     │
  │←── {"ip":"...","ok":1} ──│                      │                     │
  │                          │←── PROV_DONE_BIT ────│                     │
  │←── ble_prov_stop() ──────│                      │                     │
```

### Component Map

```
firmware/
├── main/
│   └── main.c                          ← app_main() entry point
└── components/
    ├── drivers/
    │   ├── i2c_bus/                    ← Shared I2C bus init (400 kHz)
    │   ├── i2c_devices/
    │   │   ├── sht3x/                  ← Temperature/humidity (0x44)
    │   │   └── ds3231/                 ← RTC (0x68)
    │   ├── spi_bus/                    ← Shared SPI2_HOST init
    │   ├── spi_devices/
    │   │   ├── st7789/                 ← TFT display (10 MHz)
    │   │   └── xpt2046/                ← Touch controller (2 MHz)
    │   ├── sdmmc/                      ← SD card SDIO driver
    │   └── general/
    │       ├── ble_prov/               ← BLE GATT provisioning server
    │       ├── wifi/                   ← WiFi station mode (event-driven)
    │       ├── mqtt/                   ← MQTT client (TLS, LWT, QoS1)
    │       ├── webserver/              ← HTTP config server + mDNS
    │       └── dns/                    ← Captive DNS (~169 lines, implemented)
    ├── config/                         ← Kconfig + NVS config access
    ├── core/                           ← sysload.c, version.c
    └── ota/                            ← HTTPS OTA + rollback + validate task
```

> **Component status (2026-04-13):** Hầu hết là stub. Chỉ `dns.c` có implementation thực chất. Xem `tasks/knowledge.md` để biết trạng thái từng component.

### FreeRTOS Task Map

| Task           | Core | Priority | Stack (B) | Role                               |
| -------------- | ---- | -------- | --------- | ---------------------------------- |
| `prov_task`    | 1    | 7        | 4096      | BLE provisioning (one-shot)        |
| `mqtt_task`    | 1    | 6        | 6144      | Publish telemetry, handle commands |
| `sensor_task`  | 1    | 5        | 4096      | Poll SHT3x + DS3231 every 30 s     |
| `display_task` | 0    | 4        | 8192      | Render UI on ST7789                |
| `ota_task`     | 1    | 3        | 8192      | HTTPS OTA download + validate      |
| `sd_log_task`  | 0    | 2        | 4096      | Write sensor logs to SD card       |

### Bus Architectures

```
I2C — Shared master (400 kHz)
    ├── SHT3x  @ 0x44  — temperature + humidity
    └── DS3231 @ 0x68  — real-time clock
    (API: i2c_master v5.x — NOT legacy i2c_master_cmd_begin)
    (Each device: own i2c_master_dev_handle_t)

SPI2_HOST — Shared bus
    ├── ST7789  (display) — 10 MHz, CPOL=0 CPHA=0
    └── XPT2046 (touch)  —  2 MHz → separate slow spi_device_handle_t
```

### MQTT Topics (Firmware side)

```
device/{deviceId}/status          → broker  : LWT online/offline + firmware ver
device/{deviceId}/telemetry       → broker  : sensor data (temperature, humidity, time)
device/{deviceId}/command         ← broker  : control command from app
device/{deviceId}/response        → broker  : command execution result
device/{deviceId}/shadow/report   → broker  : current state on boot/change
device/{deviceId}/shadow/get      → broker  : request desired state on boot
device/{deviceId}/ota/update      ← broker  : trigger OTA (URL + expected hash)
device/{deviceId}/ota/progress    → broker  : OTA download progress %
```

---

## Layer 3 — Cloud Infrastructure

Self-hosted trên Raspberry Pi 4 (dev/beta) → migrate lên VPS Hetzner (production).
Tất cả services chạy Docker Compose.

### Docker Compose Services

| Service     | Image                             | Ports                      | Role                                  |
| ----------- | --------------------------------- | -------------------------- | ------------------------------------- |
| `nginx`     | nginx:alpine                      | 80, 443                    | Reverse proxy + SSL termination       |
| `emqx`      | emqx:5                            | 1883, 8883(TLS), 8083(WS)  | MQTT broker                           |
| `api`       | custom (Node.js + Fastify)        | 3000 (internal)            | REST API + MQTT bridge                |
| `postgres`  | timescale/timescaledb:latest-pg15 | 5432 (internal)            | Main DB + time-series telemetry       |
| `redis`     | redis:7-alpine                    | 6379 (internal)            | Shadow · session · queue · rate-limit |
| `grafana`   | grafana/grafana                   | 3001 (internal, via nginx) | Telemetry dashboards                  |
| `pgadmin`   | dpage/pgadmin4                    | (internal only)            | DB admin UI                           |
| `portainer` | portainer/portainer-ce            | 9000 (internal)            | Docker container management           |

### Nginx Routing

```
/api/*       → api:3000        (REST API)
/ws          → emqx:8083       (MQTT WebSocket for Flutter)
/grafana     → grafana:3001    (dashboards)
:8883        → emqx:8883       (MQTT TLS for ESP32)
```

---

## Layer 4 — Database Schema

### Full Schema (PostgreSQL 15 + TimescaleDB)

```sql
-- ══════════════════════════════
-- USERS & AUTH
-- ══════════════════════════════
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

-- ══════════════════════════════
-- HOMES & ROOMS
-- ══════════════════════════════
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

-- ══════════════════════════════
-- DEVICE TYPES
-- ══════════════════════════════
CREATE TABLE device_types (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR NOT NULL,          -- e.g. "smart_air_v1"
    display_name    VARCHAR,
    icon            VARCHAR,
    spec            JSONB NOT NULL
    -- {"properties":[{"key":"temperature","type":"float","unit":"°C"},
    --                {"key":"humidity","type":"float","unit":"%"}]}
);

-- ══════════════════════════════
-- DEVICES
-- ══════════════════════════════
CREATE TABLE devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_id         UUID REFERENCES homes(id),
    room_id         UUID REFERENCES rooms(id),
    type_id         UUID REFERENCES device_types(id),
    owner_id        UUID REFERENCES users(id),
    name            VARCHAR NOT NULL,
    secret_key      VARCHAR UNIQUE NOT NULL,   -- MQTT auth (never in source)
    firmware_ver    VARCHAR,
    online          BOOLEAN DEFAULT false,
    last_seen       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════
-- DEVICE SHADOW (Redis primary + PostgreSQL backup)
-- ══════════════════════════════
CREATE TABLE device_shadows (
    device_id       UUID PRIMARY KEY REFERENCES devices(id),
    reported        JSONB DEFAULT '{}',  -- actual state from device
    desired         JSONB DEFAULT '{}',  -- target state from app
    updated_at      TIMESTAMPTZ DEFAULT NOW()
    -- delta = desired - reported (computed at query time)
);

-- ══════════════════════════════
-- COMMANDS
-- ══════════════════════════════
CREATE TABLE commands (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID REFERENCES devices(id),
    user_id         UUID REFERENCES users(id),
    payload         JSONB NOT NULL,
    status          VARCHAR DEFAULT 'pending', -- pending → sent → done | failed
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    executed_at     TIMESTAMPTZ
);

-- ══════════════════════════════
-- TELEMETRY (TimescaleDB hypertable)
-- ══════════════════════════════
CREATE TABLE telemetry (
    device_id       UUID NOT NULL,
    ts              TIMESTAMPTZ NOT NULL,
    payload         JSONB NOT NULL
    -- {"temperature":28.5,"humidity":65.2}
);
SELECT create_hypertable('telemetry', 'ts');
SELECT add_retention_policy('telemetry', INTERVAL '1 year');

-- ══════════════════════════════
-- AUTOMATIONS
-- ══════════════════════════════
CREATE TABLE automations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_id         UUID REFERENCES homes(id),
    user_id         UUID REFERENCES users(id),
    name            VARCHAR NOT NULL,
    enabled         BOOLEAN DEFAULT true,
    trigger         JSONB NOT NULL,
    -- {"type":"telemetry","device_id":"…","property":"temperature","operator":">","value":30}
    -- {"type":"schedule","cron":"0 8 * * *"}
    action          JSONB NOT NULL,
    -- {"device_id":"…","command":{"power":false}}
    last_triggered  TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════
-- NOTIFICATIONS
-- ══════════════════════════════
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id),
    title           VARCHAR NOT NULL,
    body            VARCHAR,
    type            VARCHAR,   -- alert | info | command_result
    read            BOOLEAN DEFAULT false,
    payload         JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE fcm_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id),
    token           VARCHAR NOT NULL,
    platform        VARCHAR,   -- ios | android
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Layer 5 — Node.js API (Fastify)

### Folder Structure

```
api/src/
├── index.js
├── config/
│   ├── db.js               ← PostgreSQL pool
│   ├── redis.js            ← Redis client
│   └── mqtt.js             ← EMQX internal connection
├── routes/
│   ├── auth.js
│   ├── users.js
│   ├── homes.js
│   ├── rooms.js
│   ├── devices.js
│   ├── commands.js
│   ├── telemetry.js
│   ├── automations.js
│   └── notifications.js
├── services/
│   ├── auth.service.js         ← JWT (access 15 min, refresh 30 d)
│   ├── device.service.js       ← CRUD + online/offline detection
│   ├── shadow.service.js       ← Redis primary + PostgreSQL backup
│   ├── command.service.js      ← Online direct + offline queue
│   ├── mqtt.service.js         ← EMQX bridge: subscribe all device topics
│   ├── automation.service.js   ← Evaluate trigger conditions
│   └── notification.service.js ← FCM push via Firebase Admin SDK
├── middlewares/
│   ├── auth.js             ← JWT verify (Bearer token)
│   ├── rateLimit.js        ← Redis-backed rate limiting
│   └── validate.js         ← Request schema validation
└── jobs/
    ├── offline-check.js    ← Detect device offline via MQTT LWT
    └── automation.js       ← Cron-scheduled automation runner
```

### API Endpoints

```
AUTH
  POST /api/auth/register
  POST /api/auth/login
  POST /api/auth/refresh
  POST /api/auth/logout
  POST /api/auth/verify-email

USERS
  GET  /api/users/me
  PUT  /api/users/me
  POST /api/users/me/fcm-token        ← register FCM push token

HOMES
  GET    /api/homes
  POST   /api/homes
  PUT    /api/homes/:id
  DELETE /api/homes/:id
  POST   /api/homes/:id/invite        ← invite member

ROOMS
  GET    /api/homes/:homeId/rooms
  POST   /api/homes/:homeId/rooms
  PUT    /api/rooms/:id
  DELETE /api/rooms/:id

DEVICES
  GET    /api/devices
  POST   /api/devices                 ← register after BLE provisioning
  GET    /api/devices/:id
  PUT    /api/devices/:id
  DELETE /api/devices/:id
  GET    /api/devices/:id/shadow      ← current reported/desired/delta
  POST   /api/devices/:id/command     ← send control command
  GET    /api/devices/:id/commands    ← command history
  GET    /api/devices/:id/telemetry?from=&to=

AUTOMATIONS
  GET    /api/automations
  POST   /api/automations
  PUT    /api/automations/:id
  DELETE /api/automations/:id
  PATCH  /api/automations/:id/toggle

NOTIFICATIONS
  GET    /api/notifications
  PATCH  /api/notifications/:id/read
```

### Device Shadow & Command Queue

```
CASE 1: Device ONLINE → điều khiển ngay

App               API           Redis Shadow        ESP32
 ├─POST /command─→│             │                    │
 │                ├─update desired──────────────────→│
 │                ├─MQTT publish command────────────→│
 │                │             │                    ├─execute
 │                │←────────────response─────────────│
 │←─notification──│             │                    │

CASE 2: Device OFFLINE → queue lại

App               API           Redis/DB            ESP32
 ├─POST /command─→│             │                    │
 │                ├─queue cmd──→│                    │
 │←─"queued"──────│             │         (reconnect)│
 │                │             │←───────online msg──│
 │                │             ├─flush pending cmds→│
 │                │             │                    ├─execute
 │←─notification──│←────────────────────────────────│
```

---

## Layer 6 — Mobile App (`app/`)

Flutter (iOS + Android). Adaptive theming qua `AppPalette` — all colors via `context.colors`. `AppState.themeMode` (ValueNotifier) drives full MaterialApp rebuild on theme change.

### App Feature → Transport Map

| Feature              | Transport     | Notes                                       |
| -------------------- | ------------- | ------------------------------------------- |
| BLE provisioning     | BLE GATT      | Scan → connect → write SSID/pass → notify   |
| Auth                 | HTTPS REST    | JWT access (15 min) + refresh token (30 d)  |
| Device list + shadow | HTTPS REST    | Fetch shadow state on load                  |
| Realtime status      | MQTT over WSS | Subscribe `device/+/status` + `+/telemetry` |
| Send command         | HTTPS REST    | POST → queued if device offline             |
| Telemetry chart      | HTTPS REST    | `fl_chart` — query by time range            |
| Push notification    | FCM           | Register token on login                     |
| OTA trigger          | HTTPS REST    | POST → API → MQTT → device                  |

### BLE Provisioning Flow (App Side)

```
1. Scan BLE → detect device advertising provisioning service UUID
2. Connect GATT
3. Subscribe characteristic 0xFF03 (notify)
4. Write 0xFF01 → SSID
5. Write 0xFF02 → Password
6. Wait for notify: {"ip":"…","status":"ok"}
7. POST /api/devices  ← register device in backend
8. Navigate to device detail screen
```

---

## Cross-Cutting Concerns

| Concern        | Approach                                                           |
| -------------- | ------------------------------------------------------------------ |
| Error handling | `esp_err_t` + `ESP_ERROR_CHECK` everywhere; `ESP_LOGx` + TAG       |
| Config/secrets | Kconfig for build-time; NVS for runtime — never in source          |
| Task model     | `xTaskCreatePinnedToCore`; ISR → queue handoff, no blocking in ISR |
| Persistence    | NVS for config/credentials; SD card for sensor log CSV             |
| OTA            | HTTPS only, embedded CA cert, rollback + validation task           |
| MQTT auth      | Per-device secret key from NVS; TLS mandatory                      |
| JWT            | Access: 15 min; Refresh: 30 d; sessions in Redis                   |
| Rate limiting  | Redis-backed per-IP per-endpoint in API layer                      |
| Telemetry TTL  | TimescaleDB retention policy → auto-drop data older than 1 year    |

---

## Security Rules

| Rule   | Constraint                                                                      |
| ------ | ------------------------------------------------------------------------------- |
| SEC-01 | No hardcoded credentials — MQTT key, WiFi password, API secrets via NVS/Kconfig |
| SEC-02 | OTA over HTTPS only — embedded CA cert (`_binary_*_pem_start`)                  |
| SEC-03 | OTA rollback required — validation task must confirm before committing update   |
| SEC-04 | MQTT TLS mandatory for all device-to-broker communication                       |
| SEC-05 | JWT in Authorization header only — never in URL                                 |

---

## Directory Reference

| Path                    | Contents                                         |
| ----------------------- | ------------------------------------------------ |
| `firmware/`             | ESP-IDF v5.x source — components, main           |
| `app/`                  | Flutter app — iOS + Android                      |
| `hardware/`             | KiCad v8 schematics + PCB                        |
| `docs/`                 | ARCHITECTURE, CONSTRAINTS, DECISIONS             |
| `TODO.md`               | Active tasks and in-progress session notes       |
| `.claude/agents/`       | Specialized agent definitions (load on demand)   |
| `.claude/skills/`       | Domain skill files (load on demand)              |
| `.claude/knowledge/`    | Long-term wiki + raw research + agent output     |

---

## Web Admin — Tools Used (Not Custom Built)

| Tool           | Purpose                           |
| -------------- | --------------------------------- |
| EMQX Dashboard | Monitor MQTT, device connections  |
| Grafana        | Telemetry charts + system metrics |
| pgAdmin        | Database management               |
| Portainer      | Docker container management       |

---

## See also

- [[CONSTRAINTS]] — Hard limits enforced at all layers
- [[DECISIONS]] — ADRs that shaped these design choices
