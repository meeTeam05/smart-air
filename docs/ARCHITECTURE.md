# ARCHITECTURE.md

This document describes the current actual architecture of `smart-air` as implemented in the repository today. It covers the full stack:

- firmware on ESP32-S3
- backend services and infrastructure
- Flutter mobile app
- the contracts and data flows that connect them

The final section, **Ideal Architecture**, is intentionally separate. It describes the target end state that should be built next based on known gaps and the realtime architecture review.

## 1. System Overview

`smart-air` is a single IoT system with three runtime boundaries:

1. **Device runtime** on ESP32-S3 using ESP-IDF
2. **Cloud/runtime stack** in Docker Compose using Fastify, EMQX, PostgreSQL/TimescaleDB, Redis, Nginx, Grafana, and Cloudflare Tunnel
3. **Mobile app** in Flutter using Riverpod, GoRouter, REST APIs, and an API-owned realtime stream

At a high level:

```text
ESP32-S3 firmware
  -> publishes telemetry, shadow, status, OTA progress over MQTT
  -> receives commands, shadow sync, OTA triggers over MQTT

EMQX broker
  -> transports device traffic

Fastify API
  -> owns user auth, home/device authorization, device registration, command enqueueing,
     MQTT ingestion, shadow persistence, telemetry persistence, and app-facing realtime

PostgreSQL / TimescaleDB
  -> canonical system of record for app data, commands, shadow persistence, and telemetry history

Redis
  -> cache and transient coordination layer

Flutter app
  -> uses REST for auth, provisioning, snapshots, history, and commands
  -> uses SSE from the API for live device updates
```

The current app does **not** connect directly to MQTT. The public MQTT-over-WebSocket endpoint exists for broker access, but the implemented app architecture is **REST + API-owned SSE**.

Current end-to-end data path from sensor to UI:

```text
+--------------------------- Device ---------------------------+
| Sensors / RTC / Relay state                                  |
|    |                                                         |
|    v                                                         |
| sensor_task / device_mode / relay                            |
|    |                                                         |
|    v                                                         |
| MQTT client on ESP32-S3                                      |
+-------------------------------+------------------------------+
                                |
                                | MQTT over WSS/TLS
                                v
+--------------------------- Server ----------------------------+
| EMQX broker                                                   |
|    |                                                          |
|    v                                                          |
| Fastify MQTT bridge                                           |
|    |                                                          |
|    +--> PostgreSQL / TimescaleDB  (canonical history/state)   |
|    |                                                          |
|    +--> Redis                 (cache / transient markers)     |
|    |                                                          |
|    +--> realtime_events + pg_notify                           |
|                          |                                    |
|                          v                                    |
|                      SSE /api/realtime                        |
+-------------------------------+-------------------------------+
                                |
                                | HTTPS + SSE
                                v
+---------------------------- App -----------------------------+
| Dio REST client           Dio SSE client                     |
|       |                       |                              |
|       +-------> Riverpod providers <------------------------+|
|                           |                                  |
|                           v                                  |
|                        Flutter UI                            |
+--------------------------------------------------------------+
```

## 2. Current Runtime Topology

### 2.1 Public ingress

Public ingress is:

```text
Internet
  -> Cloudflare Tunnel
  -> Nginx
  -> API / EMQX WSS / Grafana / OTA file hosting
```

Current public paths:

- `/api/*` -> Fastify API
- `/api/realtime` -> SSE stream from Fastify
- `/mqtt` -> MQTT over WebSocket proxied to EMQX `8083`
- `/grafana/` -> Grafana behind Nginx
- `/ota/` -> firmware binaries served by Nginx from `server/ota-files`

Direct host exposure is intentionally limited:

- `127.0.0.1:18083` -> EMQX dashboard
- `127.0.0.1:5050` -> pgAdmin (profile `admin`)
- `127.0.0.1:9000` -> Portainer (profile `admin`)
- `${MQTT_LAN_BIND_IP:-0.0.0.0}:8883` -> optional direct MQTT/TLS path

The normal public device path is `wss://minhnhat05.xyz/mqtt` through Cloudflare Tunnel and Nginx, not a raw public EMQX port.

### 2.2 Docker Compose services

`server/docker-compose.yml` defines these primary services:

- `nginx`: reverse proxy and OTA file host
- `emqx`: MQTT broker
- `api`: Fastify application
- `postgres`: TimescaleDB/PostgreSQL
- `redis`: cache and transient coordination
- `grafana`: dashboards
- `cloudflared`: public ingress tunnel

Optional admin services:

- `pgadmin`
- `portainer`

All core services run on the internal Docker bridge network `sa-net`.

## 3. Firmware Architecture

### 3.1 Firmware role

The firmware is the device-side runtime for:

- BLE Wi-Fi provisioning
- local HTTP credential handoff
- Wi-Fi connection
- best-effort SNTP clock sync
- MQTT connection and command handling
- sensor polling and telemetry publishing
- relay control
- device mode state
- OTA download and validation
- physical factory reset
- NVS-backed persistent configuration

The firmware is implemented with ESP-IDF v5.x and uses `app_main()` as the entrypoint.

Firmware internal architecture:

```text
+--------------------------- ESP32-S3 --------------------------+
| app_main                                                      |
|   |                                                           |
|   v                                                           |
| sysload_init                                                  |
|   |                                                           |
|   +--> config / NVS  <-------------------------------+        |
|   +--> wifi_sta                                      |        |
|   +--> ble_prov                                      |        |
|   +--> httpd (/api/info, /api/config)                |        |
|   +--> mqtt client ----------------------------------+        |
|   +--> ota task                                               |
|   +--> sensor_task                                            |
|   +--> device_mode                                            |
|   +--> relay                                                  |
|   +--> factory_reset                                          |
|   +--> led / buzzer                                           |
+-------------------------+-------------------------------------+
                          |
        +-----------------+-----------------+
        |                 |                 |
        v                 v                 v
   I2C bus            ADC1 inputs       GPIO / SPI
   - SHT3x            - CO sensor       - relays
   - DS3231           - NO2 sensor      - LED
                                          - reset button
                                          - ILI9225 on SPI2_HOST
                                          - SD Card on SPI3_HOST
```

### 3.2 Boot and orchestration

`firmware/components/core/sysload/sysload.c` is the boot orchestrator. The implemented boot order is:

1. Initialize LED so status is visible immediately
2. Initialize factory reset button early
3. Initialize NVS
4. Initialize network/event loop
5. Initialize I2C bus when needed
6. Initialize sensors and RTC when enabled
7. Initialize ADC bus and gas sensors when enabled
8. Initialize Wi-Fi station
9. If Wi-Fi is not provisioned, enter BLE provisioning flow
10. Load stored Wi-Fi credentials and connect to Wi-Fi
11. Attempt one-shot SNTP sync, then persist the synced timestamp to DS3231 when RTC is available
12. Resolve immutable device ID from Wi-Fi STA MAC
13. Load MQTT broker URI and device secret from NVS, falling back to Kconfig defaults
14. Start local HTTP provisioning API
15. If no MQTT secret exists yet, stop here and wait for local `/api/config`
16. Initialize buzzer, relays, and device mode
17. Register MQTT command handlers
18. Register time sync callback
19. Start MQTT client
20. Start OTA task
21. Start sensor task
22. Validate and commit pending OTA image after system startup

This ordering matters:

- the device can join Wi-Fi before it has per-device MQTT credentials
- the local HTTP provisioning API must exist before first MQTT login
- command handlers are registered before MQTT starts
- OTA validation happens after the system proves it booted successfully

### 3.3 Peripheral and bus topology

The firmware is built around a fixed hardware topology that the code assumes today:

- `ESP32-S3` is the central MCU
- `SHT3x` temperature/humidity sensor is on I2C at `0x44`
- `DS3231` RTC is on I2C at `0x68`
- `ILI9225` display is on `SPI2_HOST`
- `SD Card` uses `SPI3_HOST`
- `CO` and `NO2` analog sensors use `ADC1`
- three relay channels are controlled by dedicated GPIO outputs
- LED and factory reset button are separate GPIO-backed peripherals

Current architectural constraints encoded in code and config:

- I2C runs at the configured shared bus frequency for sensor peripherals
- display and SD card do not share the same SPI host
- gas sensors stay on Wi-Fi-safe `ADC1`
- demo mode disables selected peripherals but does not remove relay, LED, or factory reset support

### 3.4 Configuration and persistent state

Configuration is split between Kconfig defaults and NVS overrides.

### Compile-time configuration

`firmware/components/config/include/config.h` exposes project-wide flags and constants. Current behavior:

- `SA_ENABLE_LED`
- `SA_ENABLE_FACTORY_RESET`
- `SA_ENABLE_RELAYS`

are enabled independently of demo mode.

`SA_DEMO_NO_PERIPHERALS` disables these peripheral groups:

- `SHT3X`
- `DS3231`
- `CO sensor`
- `NO2 sensor`
- `ILI9225`
- `SD card`
- `buzzer`

It does **not** disable:

- relays
- LED
- factory reset

That means demo mode can still use real GPIO relays when relay support is enabled.

### NVS responsibilities

`firmware/components/config/config.c` and related modules use NVS for:

- Wi-Fi provisioning data in namespace `wifi_prov`
- device MQTT `secret_key`
- optional MQTT `broker_uri` override
- gas calibration baselines
- persisted device mode
- persisted relay states

The device ID itself is not mutable configuration. It is always derived from the Wi-Fi STA MAC and normalized to lowercase `aa:bb:cc:dd:ee:ff`.

`config_get_mqtt_creds()` falls back to Kconfig defaults when NVS values are absent. `config_set_mqtt_config()` validates:

- device ID matches the actual MAC
- secret key is non-empty
- broker URI is supported

It also clears the legacy stored `device_id` key.

### NVS write coordination

The firmware uses explicit guards for:

- normal NVS writes
- factory reset erase coordination

This prevents concurrent writes while factory reset is erasing the default NVS partition.

### 3.5 Provisioning architecture

Provisioning is split into two distinct steps because Wi-Fi credentials and MQTT credentials do not come from the same trust boundary.

BLE and local provisioning flow:

```text
+---------------- App ----------------+        +--------------- Device ---------------+         +-------------- Server --------------+
| Flutter provisioning screens        |        | ESP32-S3                              |        | Fastify API + EMQX                 |
|                                     |        |                                       |        |                                    |
| 1. scan BLE ----------------------> |        | advertises SMART_AIR_<suffix>         |        |                                    |
| 2. connect + send SSID/password --->|------->| NimBLE GATT service                   |        |                                    |
|                                     |        |   -> Wi-Fi connect                    |        |                                    |
|                                     |        |   -> best-effort SNTP sync            |        |                                    |
| <--- 3. notify {device_id, ip} -----|<-------|   -> save wifi_prov in NVS            |        |                                    |
|                                     |        |                                       |        |                                    |
| 4. POST /api/devices ------------------------------------------------------------------------>| create device row + EMQX user/ACL  |
| <--- 5. {secret_key,...} ---------------------------------------------------------------------| return one-time MQTT secret        |
|                                     |        |                                       |        |                                    |
| 6. POST http://<device-ip>/api/config ------------------------------------------------------->| local HTTP server validates MAC    |
|                                     |        |   -> save secret_key/broker_uri in NVS|        |                                    |
|                                     |        |   -> reboot                           |        |                                    |
| 7. poll /api/devices/announce/:mac ---------------------------------------------------------> | wait for online announce           |
| <--- 8. announced=true -----------------------------------------------------------------------|                                    |
+-------------------------------------+        +---------------------------------------+        +------------------------------------+
```

### Step 1: BLE Wi-Fi provisioning

`firmware/components/general/ble_prov/ble_prov.c` implements BLE provisioning using NimBLE.

Current behavior:

- advertises as `SMART_AIR_<suffix>`
- exposes a custom GATT service
- accepts SSID and password over writable characteristics
- attempts Wi-Fi connect
- performs one bounded SNTP sync attempt after Wi-Fi connect, then writes the synced timestamp to DS3231 if available
- persists Wi-Fi credentials into NVS namespace `wifi_prov`
- notifies the app with JSON status, including device IP and device ID on success

BLE provisioning is only for Wi-Fi onboarding. It does not provision MQTT credentials.

### Step 2: local HTTP MQTT credential handoff

After Wi-Fi is available, the firmware exposes a local HTTP server in `firmware/components/general/httpd/httpd.c`.

Current endpoints:

- `GET /api/info`
  - returns `device_id`, `firmware`, and current IP
- `POST /api/config`
  - accepts first MQTT credential set from the app
  - requires `device_id` and `secret_key`
  - optionally accepts `broker_uri`
  - refuses to overwrite an already-provisioned MQTT secret
  - validates that the incoming `device_id` matches the device MAC
  - persists config to NVS
  - reboots after success

This local HTTP hop is how the app delivers per-device MQTT credentials issued by the server.

### 3.6 Network and MQTT architecture

`firmware/components/general/sa_mqtt/mqtt.c` implements the device MQTT client.

Current behavior:

- connects using the device ID as:
  - MQTT username
  - MQTT client ID
- uses the server-issued `secret_key` as MQTT password
- connects to the configured broker URI, typically `wss://.../mqtt`
- uses certificate bundle verification
- publishes retained online status on connect
- configures a retained LWT offline status
- subscribes inside `MQTT_EVENT_CONNECTED` to ensure reconnect re-subscription
- copies incoming topic and payload buffers before processing

Current subscribed topics:

- `device/{id}/command`
- `device/{id}/shadow/get_response`
- `device/{id}/ota/update`

Current published topics include:

- `device/{id}/status`
- `device/{id}/telemetry`
- `device/{id}/response`
- `device/{id}/shadow/report`
- `device/{id}/shadow/get`
- `device/{id}/ota/progress`

### 3.7 Command handling

Firmware command dispatch is registry-based. `sysload.c` registers handlers with `mqtt_register_command_handler()`.

Currently implemented command paths:

- `relay_set`
- `device_mode`
- `set_time`
- `calibrate_co`
- `calibrate_no2`

Behavioral notes:

- `set_time` is handled specially by the MQTT layer and forwarded to a time sync callback
- boot also performs a best-effort SNTP sync after Wi-Fi connect; if SNTP fails or times out, firmware falls through to existing fallback behavior
- unsupported command types are acknowledged with `status: "error"`
- `set_config` is explicitly rejected over MQTT; local `/api/config` is the supported path
- OTA does not use the generic command topic; it uses `device/{id}/ota/update`

Responses are published to `device/{id}/response` after command execution completes, either inline in the MQTT callback or later from a worker task for longer operations.

### 3.8 Sensors and telemetry

`firmware/components/core/sensor_task/sensor_task.c` is the telemetry publisher.

Current behavior:

- polls on `SA_SENSOR_POLLING_INTERVAL`
- publishes telemetry JSON to `device/{id}/telemetry`
- publishes reported sensor state to `device/{id}/shadow/report`
- uses RTC time when available, otherwise system time
- publishes `null` for unavailable sensor fields rather than changing schema

Current telemetry fields:

- `device_id`
- `mode`
- `ts`
- `temperature`
- `humidity`
- `co_ppm`
- `no2_ppm`

### Demo mode

When `SA_DEMO_NO_PERIPHERALS` is enabled:

- the sensor task injects a deterministic rotating sample set
- telemetry schema and topics stay unchanged
- downstream MQTT, server, shadow, and app flows remain the same

This is an architectural choice: demo mode changes data sources, not the transport contract.

### 3.9 Device mode and relay control

`firmware/components/core/device_mode/device_mode.c` manages global device mode.

Current behavior:

- persists mode in NVS
- exposes `device_mode_get()`
- publishes mode-driven telemetry/shadow transitions
- gates whether the sensor task publishes data

When switching to `off`:

- sensor publishing is disabled
- final null telemetry is published
- all relays are forced off
- a mode-off shadow report is published
- mode is persisted

When switching to `on`:

- mode is persisted
- sensor publishing is re-enabled
- current relay states are included in the new shadow report

`firmware/components/general/relay/relay.c` implements relay control on real GPIO.

Current relay behavior:

- relays are backed by real GPIO in both normal mode and demo mode
- relay state is restored from NVS on boot
- `relay_set()` refuses changes when device mode is off
- successful changes persist state, beep the buzzer, and publish shadow deltas

There is no separate virtual relay layer in demo mode.

### 3.10 Factory reset

`firmware/components/general/factory_reset/factory_reset.c` implements hold-to-reset on a physical button.

Current behavior:

- polls every 50 ms
- shows LED feedback during hold
- on trigger:
  - stops Wi-Fi
  - stops MQTT
  - erases the default NVS partition
  - reboots back into provisioning

Reset scope explicitly includes:

- Wi-Fi provisioning
- MQTT credentials and broker override
- device mode
- gas calibration
- other firmware state in the default NVS partition

### 3.11 OTA architecture

`firmware/components/ota/ota.c` implements HTTPS OTA.

Current behavior:

- OTA is triggered from MQTT topic `device/{id}/ota/update`
- OTA payload includes URL and SHA-256
- firmware downloads over HTTPS only
- progress is published to `device/{id}/ota/progress`
- SHA-256 is verified before `esp_https_ota_finish()`
- the device reboots into the new image
- `ota_validate_and_commit()` marks the image valid after a successful boot

Nginx serves OTA artifacts from `server/ota-files` under `/ota/`.

The firmware side is implemented. The app-facing OTA trigger flow is not yet exposed in the mobile UI.

## 4. Server Architecture

### 4.1 Server role

The server is the trust boundary for:

- user authentication
- home membership and device ownership
- device registration
- EMQX user and ACL provisioning
- MQTT bridge ingestion
- telemetry persistence
- command queueing and status tracking
- shadow state persistence
- app-facing realtime fanout

The main API entrypoint is `server/api/src/app.js`.

It registers these core plugins:

- `db`
- `redis`
- `auth`
- `mqtt`
- `realtime`

### 4.2 API layer

The Fastify API owns all app-facing business operations.

Primary route groups:

- auth
- homes
- rooms
- devices
- shadow
- commands
- telemetry
- realtime
- health

Important architectural properties:

- JWT bearer auth is the only app auth model
- access control is checked per home/device on server side
- API startup is guarded by required environment variables
- request logging redacts sensitive fields
- readiness includes PostgreSQL, Redis, EMQX Admin API, MQTT bridge, and realtime listener

### 4.3 Persistent data model

PostgreSQL/TimescaleDB is the canonical source of truth for persistent application data.

Core tables from migrations include:

- `users`
- `refresh_tokens`
- `homes`
- `home_members`
- `rooms`
- `device_types`
- `devices`
- `device_shadows`
- `commands`
- `telemetry`
- `realtime_events`
- plus automation/notification-related tables for future or partial use

Important storage roles:

- `devices`: inventory, ownership, online/firmware metadata, secret hash
- `device_shadows`: reported and desired state snapshots
- `commands`: queued and executed device commands
- `telemetry`: time-series sensor data in a hypertable
- `realtime_events`: durable app-facing event log for SSE replay

Telemetry is persisted before app realtime fanout so historical and live views come from the same canonical path.

### 4.4 Redis role

Redis is used as a transient coordination and cache layer, not the canonical system of record.

Current roles include:

- shadow cache
- device announce markers used during provisioning
- OTA progress cache
- other transient runtime coordination

Shadow behavior is explicitly DB-first, cache-second:

- DB is written first
- Redis is written through from the canonical DB result
- cache failures degrade gracefully back to DB reads

### 4.5 EMQX and broker authorization

EMQX is the MQTT broker for device traffic.

The server provisions broker credentials and ACLs through the EMQX Admin API in `server/api/src/services/emqx.js`.

### Device identity and auth

Per-device MQTT identity is:

- `username = device_id`
- `password = secret_key`

The device secret is created at registration time by the API and returned once to the app for local provisioning into the device.

The `devices` table stores only a hash of the secret.

### Bridge identity

The internal server MQTT bridge uses:

- username `sa-server` by default
- password from `EMQX_MQTT_PASSWORD`

Its ACLs allow:

- subscribe to device status/telemetry/response/shadow/OTA progress
- publish device commands and shadow responses

### Registration flow

`POST /api/devices` performs the device registration transaction:

1. validate home and room access
2. generate `secret_key`
3. create EMQX user and ACL
4. insert device row
5. return device metadata plus one-time `secret_key`

If EMQX provisioning succeeds but the DB insert later fails, the API attempts compensating cleanup so broker auth does not drift from the database.

### 4.6 MQTT bridge and ingestion

`server/api/src/plugins/mqtt.js` runs the internal MQTT bridge.

Current behavior:

- connects to EMQX over `mqtt://emqx:1883` inside Docker
- uses persistent subscriptions
- subscribes to:
  - `device/+/status`
  - `device/+/telemetry`
  - `device/+/response`
  - `device/+/shadow/report`
  - `device/+/shadow/get`
  - `device/+/ota/progress`
- uses manual QoS acknowledgements
- leaves a message unacked if handler execution fails, allowing redelivery

`server/api/src/services/mqtt-handlers.js` is the ingestion boundary for device-originated MQTT messages.

Current server-side handlers:

- `handleStatus`
- `handleTelemetry`
- `handleResponse`
- `handleShadowReport`
- `handleShadowGet`
- `handleOtaProgress`

Architectural rules implemented there:

- ignore data from unknown devices
- validate telemetry and shadow payload shape
- clamp invalid telemetry timestamps into a sane range
- persist canonical state first
- then emit app-facing realtime events

### 4.7 Command architecture

Commands are app-originated but device-executed.

Current flow:

```text
App REST request
  -> API validates auth and access
  -> API inserts command row with status=pending
  -> API emits realtime event: command.updated pending
  -> if MQTT bridge is ready, pending queue is flushed
  -> command is published to device/{id}/command
  -> status becomes sent
  -> firmware executes and publishes response
  -> API updates command to done/error
  -> API emits realtime event: command.updated
```

Key implementation details:

- commands are stored in DB before publish
- pending commands survive temporary broker/device unavailability
- `flushPending()` serializes publish work per device using advisory locks
- expired pending commands become `timeout`
- typed convenience endpoints exist for:
  - `POST /devices/:id/relay/:channel`
  - `POST /devices/:id/mode`
- the generic command endpoint validates command payloads and blocks unsupported types such as `set_config` and `ota_update`

This is not fire-and-forget MQTT. It is a server-owned command queue with MQTT as the transport to the device.

### 4.8 Shadow architecture

The device shadow is split into:

- `reported`: what the device says is currently true
- `desired`: what the server wants the device to converge toward

Current behavior:

- firmware publishes `shadow/report`
- server upserts `reported`
- app can write `desired` over REST
- device can request desired state with `shadow/get`
- server publishes `shadow/get_response` with both `desired` and computed `delta`

Shadow is used for persistent state synchronization, not for all real-time control. Immediate user actions like relay toggles and mode changes go through the command path.

### 4.9 Realtime architecture

The current app-facing realtime layer is **API-owned SSE**, not direct MQTT.

Server component layout:

```text
+-------------------------------- Public ingress ----------------------------------+
| Internet -> Cloudflare Tunnel -> Nginx                                           |
|                                  |                                               |
|                                  +--> /api/* -----------> Fastify API            |
|                                  +--> /api/realtime ---> Fastify SSE stream      |
|                                  +--> /mqtt -----------> EMQX WebSocket 8083     |
|                                  +--> /grafana/ -------> Grafana                 |
|                                  +--> /ota/ -----------> OTA files               |
+-------------------------------------+--------------------------------------------+
                                      |
                                      v
+------------------------------- Internal Docker net ------------------------------+
|                                                                                  |
|  +-----------+     MQTT       +----------+                                       |
|  |   EMQX    | <------------> | Fastify  |                                       |
|  +-----------+                |   API    |                                       |
|       ^                       +-----+----+                                       |
|       |                             |                                            |
|       |                             +--> PostgreSQL / TimescaleDB                |
|       |                             +--> Redis                                   |
|       |                             +--> pg_notify / realtime listener           |
|       |                                                                      +---+-----+
|       +------------------------------------------------------------------->  | Grafana |
|                                                                              +---------+
+----------------------------------------------------------------------------------------+
```

### Durable event log

`server/db/migrations/013_realtime_events.sql` adds `realtime_events`.

The API writes durable rows for app-visible changes such as:

- `telemetry.point`
- `shadow.reported`
- `command.updated`
- `device.status`
- `ota.progress`

`server/api/src/services/realtime-events.js` handles:

- event creation
- event formatting
- event replay queries
- per-user replay authorization

Each event insert is followed by `pg_notify` on channel `realtime_events`.

### SSE fanout

`server/api/src/plugins/realtime.js` opens and maintains SSE streams for authenticated app clients.

Current behavior:

- endpoint: `GET /api/realtime`
- auth: JWT via normal API authentication
- heartbeat: periodic SSE comment frames
- replay: supports `Last-Event-ID`
- authorization: device access checked before sending each event
- recovery:
  - if replay is valid, events are replayed from `realtime_events`
  - if replay cannot be fulfilled, the client receives `replay.reset`

This keeps app realtime under the same auth and ownership model as the rest of the API.

Realtime SSE event flow:

```text
+---------------- Device ----------------+       +---------------------- Server ------------------------+       +--------------- App ------------------+
| firmware publishes MQTT message        |       |                                                      |       | Dio SSE client                       |
| - telemetry                            |-----> | EMQX -> Fastify MQTT bridge                          |-----> | GET /api/realtime                    |
| - status                               | MQTT  |   -> validate payload                                |  SSE  |   -> SseDecoder                      |
| - shadow.report                        |       |   -> persist canonical state                         |       |   -> RealtimeEvent                   |
| - command response                     |       |   -> INSERT realtime_events                          |       |   -> Riverpod listeners              |
| - ota.progress                         |       |   -> pg_notify(realtime_events)                      |       |   -> dashboard / chart / status UI   |
+----------------------------------------+       |   -> auth check per client/device before send        |       +--------------------------------------+
                                                 +------------------------------------------------------+

Replay path on reconnect:
  client sends Last-Event-ID
    -> server checks user access to replay start
    -> server replays missed realtime_events in order
    -> if replay gap cannot be served, server emits replay.reset
```

### 4.10 Health and operations

The API readiness contract includes:

- PostgreSQL
- Redis
- EMQX Admin API
- MQTT bridge readiness
- realtime listener readiness

Nginx and Docker health checks are also wired in Compose.

Grafana is present for dashboarding, but it is not in the critical app control path.

## 5. App Architecture

### 5.1 App role

The Flutter app is the user-facing control plane for:

- authentication
- home and room management
- device provisioning
- live device dashboards
- history queries
- command issuance

The app currently uses:

- Flutter
- Riverpod
- GoRouter
- Dio
- BLE for provisioning transport
- REST for canonical app operations
- SSE for live updates

### 5.2 Navigation structure

`app/lib/core/router.dart` defines routing.

Current shell structure:

- `/home`
- `/automation`
- `/notifications`
- `/profile`

The tab shell uses `StatefulShellRoute.indexedStack`, which preserves tab state.

Important non-shell drill-down routes include:

- homes
- home detail
- provisioning flow
- device dashboard
- device chart
- command history
- device settings
- calibration wizard
- OTA screen

### 5.3 Auth and session model

`app/lib/providers/auth_provider.dart` owns app auth session state.

Current behavior:

- access tokens stay in memory
- refresh token and serialized user are restored from secure storage
- forced logout invalidates app session providers
- auth state drives GoRouter redirects

The app auth model is API/JWT-based. It does not maintain separate broker credentials for the user.

### 5.4 Provisioning flow

Provisioning is a multi-transport flow:

1. App discovers and connects to the device over BLE
2. App sends Wi-Fi SSID/password over BLE
3. Device joins Wi-Fi and reports back device ID and IP
4. App calls `POST /api/devices` to register the device in the backend
5. API returns one-time `secret_key`
6. App calls the device’s local HTTP `POST /api/config` with:
   - `device_id`
   - `secret_key`
   - optional `broker_uri`
7. Device stores MQTT credentials, reboots, connects to broker
8. App polls `/api/devices/announce/:mac` to confirm the device came online

This provisioning split is intentional:

- BLE is the local trust channel for Wi-Fi bootstrap
- HTTP on the local LAN is the one-time trust channel for MQTT credentials
- server registration is the authority that creates broker access

### 5.5 App data access model

The app’s canonical data access pattern is:

- **REST** for snapshots, history, mutations, and provisioning steps
- **SSE** for live updates

Current `DeviceService` responsibilities include:

- device registration
- local device configuration
- announce polling
- device list fetch
- shadow fetch and desired updates
- command send
- relay and mode helper calls
- command history fetch
- telemetry fetch

Telemetry history is fetched over REST from `/api/devices/:id/telemetry`, optionally aggregated server-side.

### 5.6 Realtime client

`app/lib/services/realtime_service.dart` implements the current realtime transport.

Current behavior:

- opens `GET /realtime` with `Accept: text/event-stream`
- stores `Last-Event-ID` in memory during the live session
- reconnects with exponential backoff
- updates connection state:
  - `disconnected`
  - `connecting`
  - `connected`
  - `degraded`
- marks the stream as degraded on `replay.reset`

This is an app-facing SSE client built on top of Dio, not a direct MQTT client.

### 5.7 Riverpod state model

Current app state is organized around Riverpod notifiers and families.

App Riverpod state management:

```text
+----------------------------- Flutter App -----------------------------+
|                                                                       |
|  authProvider ----------------------------------------------------+   |
|      |                                                            |   |
|      v                                                            |   |
|  dioProvider / auth interceptor                                   |   |
|      |                                                            |   |
|      +-------------------- REST ----------------------------------+   |
|      |                                                                |
|      +-------------------- realtimeEventsProvider (SSE stream) -------+
|                                      |
|                                      v
|         +----------------------------+----------------------------+
|         |                            |                            |
|         v                            v                            v
|   devicesProvider              shadowProvider(id)          commandsProvider(id)
|   - list / online state        - reported/desired         - pending/sent/done/error
|                                                                   |
|                                                                   v
|                                                         telemetryLiveProvider(id)
|                                                         - rolling live buffer
|                                                         - latest point
|                                                         - realtime status
|
|   telemetryProvider(params) / telemetryHistoryProvider(params)
|   - REST snapshot / aggregated history
|
|                              |
|                              v
|                           Flutter UI
|                 screens watch provider slices, not raw timers
+-----------------------------------------------------------------------+
```

Key providers in `app/lib/providers/devices_provider.dart`:

- `devicesProvider`
- `shadowProvider(deviceId)`
- `commandsProvider(deviceId)`
- `telemetryProvider(params)`
- `telemetryLiveProvider(deviceId)`
- `telemetryHistoryProvider(params)`

Current live update pattern:

- `realtimeEventsProvider` is a shared `StreamProvider.autoDispose`
- device-specific notifiers listen to that stream
- each notifier applies only the event types relevant to its domain

Examples:

- `devicesProvider` reacts to `device.status`
- `shadowProvider` reacts to `shadow.reported`
- `commandsProvider` reacts to `command.updated`
- `telemetryLiveProvider` reacts to `telemetry.point` and `replay.reset`

### Live telemetry model

The app already separates live telemetry from historical telemetry.

`TelemetrySeriesState` currently tracks:

- rolling points
- latest point
- initial loading
- refreshing
- last error
- last updated time
- realtime connection status

This is materially better than widget-owned polling, because live state is held in Riverpod rather than recreated by screen timers.

### 5.8 Current gaps in the app

There are still important architectural limitations in the current app layer:

- realtime state is shared through a single event stream, but multiple auto-dispose notifiers subscribe independently and still carry lifecycle complexity
- OTA is visible in the UI, but update triggering is not exposed yet
- the app relies on REST polling for some command completion flows such as `waitForCommandCompletion()`
- app state is live-capable, but not yet fully centralized into a single long-lived domain store per concern

The realtime architecture is already API-owned and directionally correct, but it is not yet the final form.

## 6. Cross-Cutting Contracts and Flows

### 6.1 Identity and ownership

There are two important identity domains:

### User identity

- authenticated with JWT access tokens
- authorized through home membership and role checks

### Device identity

- immutable lowercase MAC-style `device_id`
- used consistently across firmware, MQTT topics, API routes, DB rows, and app models

Device ownership is not enforced at the broker boundary alone. The API enforces ownership and membership before exposing data or sending commands.

### 6.2 REST vs SSE vs MQTT

Current transport separation is:

### MQTT

Used for device-to-server and server-to-device transport:

- status
- telemetry
- commands
- command responses
- shadow sync
- OTA trigger
- OTA progress

### REST

Used for app-to-server request/response operations:

- auth
- homes / rooms / devices CRUD
- device registration
- shadow desired updates
- command submission
- telemetry history queries
- provisioning announce checks

### SSE

Used for server-to-app live events:

- device status changes
- new telemetry points
- shadow reports
- command status changes
- OTA progress

This separation is the current architectural center of the system.

### 6.3 MQTT topic contract

The MQTT topic contract is documented in `docs/MQTT_PROTOCOL.md` and is intended to be canonical.

Primary topics:

- `device/{deviceId}/status`
- `device/{deviceId}/telemetry`
- `device/{deviceId}/command`
- `device/{deviceId}/response`
- `device/{deviceId}/shadow/report`
- `device/{deviceId}/shadow/get`
- `device/{deviceId}/shadow/get_response`
- `device/{deviceId}/ota/update`
- `device/{deviceId}/ota/progress`

Important implementation detail: the public MQTT broker endpoint exists, but the current mobile app does not use it directly. The app contract is the API.

MQTT topic contract and direction map:

```text
Device topics are per-device:
  device/{deviceId}/...

+------------------------------ Device publishes -----------------------------+
| -> device/{id}/status              online/offline + LWT                     |
| -> device/{id}/telemetry           sensor telemetry                         |
| -> device/{id}/response            command result                           |
| -> device/{id}/shadow/report       reported state                           |
| -> device/{id}/shadow/get          request desired state                    |
| -> device/{id}/ota/progress        OTA progress                             |
+------------------------------------+----------------------------------------+
                                     |
                                     | MQTT broker transport
                                     v
+------------------------------------+----------------------------------------+
| <- device/{id}/command             relay_set / device_mode / set_time / ... |
| <- device/{id}/shadow/get_response desired + delta                          |
| <- device/{id}/ota/update          OTA trigger with URL + SHA-256           |
+------------------------------ Device subscribes ----------------------------+

Boundary note:
  Firmware <-> MQTT broker uses MQTT topics directly
  App <-> system does not use these topics directly today
  App consumes normalized REST + SSE from the API boundary
```

### 6.4 Realtime event flow

The implemented realtime event flow is:

```text
Firmware telemetry / status / response / shadow / OTA progress
  -> MQTT broker
  -> API MQTT bridge
  -> validation and persistence
  -> realtime_events insert
  -> pg_notify
  -> Fastify realtime plugin
  -> authenticated SSE clients
  -> Riverpod notifiers
  -> UI
```

The important architectural rule is that app-facing live events are emitted **after** the server accepts and persists the source change.

Normalized realtime data path:

```text
firmware MQTT message
  -> API ingestion handler
     -> validate and normalize payload
     -> persist DB/cache state
     -> create realtime_events row
     -> notify SSE clients
     -> Riverpod notifier applies event to domain state
     -> only affected UI sections rebuild
```

### 6.5 OTA flow

Current OTA flow is:

```text
Operator or future server-side OTA flow
  -> publish MQTT message to device/{id}/ota/update
  -> firmware downloads HTTPS artifact from /ota/
  -> firmware verifies SHA-256
  -> firmware reboots
  -> firmware publishes OTA progress during download
  -> API ingests progress and emits ota.progress to app realtime
```

The firmware and server ingestion pieces exist. A first-class app-triggered OTA workflow does not yet exist.

## 7. Ideal Architecture

This section is the target end state, not the current implementation.

The current system is already moving in the correct direction, especially compared with old timer-driven UI refresh patterns. The next architectural work should strengthen that design rather than reintroduce direct widget polling or app-owned MQTT complexity.

### 7.1 Realtime transport target

The target app realtime path should remain:

```text
Firmware -> MQTT -> Server persistence -> App realtime gateway -> App state store -> UI
```

and should **not** regress to:

```text
Firmware -> MQTT -> DB -> widget timer -> REST refetch whole window
```

### Recommendation

Keep the API as the app-facing realtime boundary.

- MQTT remains infrastructure for device transport
- the API remains the auth and authorization boundary
- REST remains canonical for snapshots, history, and mutations
- realtime remains server-owned and user-session-authenticated

The current SSE implementation is architecturally correct for this stack. It should be extended, not bypassed.

Ideal architecture target state:

```text
+--------------------------- Edge / Device --------------------------+
| Sensors / relays / mode / OTA                                      |
|    -> MQTT publish / subscribe                                     |
+-------------------------------+------------------------------------+
                                |
                                | MQTT
                                v
+-------------------------- Server control plane ---------------------+
| EMQX broker                                                         |
|    -> API MQTT ingestion                                            |
|    -> canonical persistence (PostgreSQL / TimescaleDB)              |
|    -> cache / transient state (Redis)                               |
|    -> realtime gateway (SSE now, WebSocket later if needed)         |
|    -> auth + ownership enforcement                                  |
+-------------------------------+-------------------------------------+
                                |
                 +--------------+---------------+
                 |                              |
                 | REST                         | Realtime
                 v                              v
+----------------------------- Mobile app ----------------------------+
| Dio REST client                single realtime session              |
|    -> history / mutations      -> domain event stream               |
|                              +-> long-lived Riverpod stores         |
|                              +-> selectors / derived provider views |
|                                             |                       |
|                                             v                       |
|                                           UI                        |
+---------------------------------------------------------------------+

Anti-target:
  device -> broker -> DB -> widget timer -> full REST reload -> flickering UI
```

### When to keep SSE vs move to WebSocket

Short term:

- keep SSE as the implemented transport because it already matches the server-owned realtime architecture

Longer term:

- evolve to a unified realtime gateway, potentially WebSocket, if the app needs richer bidirectional realtime domains such as:
  - command acknowledgements beyond stream replay
  - OTA orchestration
  - presence/session-aware features
  - multiplexed control streams

That future transport upgrade should still stay behind the API boundary. The app should not subscribe directly to broker topics as its primary runtime architecture.

### 7.2 Server-side target improvements

The next server architecture improvements should be:

1. **Strengthen realtime as a first-class domain**
   - make event schemas explicit and versioned
   - formalize event categories such as telemetry, shadow, command, device status, OTA
   - keep durable replay and backfill semantics

2. **Keep persistence-before-broadcast as a hard rule**
   - telemetry and command state should continue to hit canonical storage before fanout
   - app realtime and REST history must never diverge

3. **Expose missing control paths through the API**
   - app-facing OTA workflow
   - stronger room/home membership surface where needed
   - clearer reported vs desired shadow contracts

4. **Improve observability**
   - metrics for MQTT bridge lag, SSE client count, replay resets, event retention, command queue depth
   - clearer operational dashboards for ingestion and realtime health

5. **Harden lifecycle and integration testing**
   - end-to-end tests across MQTT ingress -> API persistence -> realtime stream -> app consumption
   - navigation and provider lifecycle tests in the app for realtime-heavy screens

### 7.3 App-side target state management

The current Riverpod design is directionally correct, but the ideal state model is more centralized and domain-oriented.

### Recommended end state

The app should converge toward:

- one authenticated app-level realtime session
- one stable live domain store per concern
- selectors or derived providers for UI slices

Recommended conceptual providers:

- `realtimeClientProvider`
  - owns connection lifecycle and replay state
- `telemetryLiveProvider(deviceId)`
  - owns rolling live telemetry buffer
- `telemetryHistoryProvider(deviceId, range)`
  - owns REST-backed historical queries
- `shadowProvider(deviceId)`
  - owns reported and desired shadow state
- `commandTimelineProvider(deviceId)`
  - owns pending/sent/done/error command lifecycle

### Why this is better

- screens stop owning refresh behavior
- UI stops reloading whole domains for small live changes
- command updates no longer force unrelated telemetry reloads
- reconnect and replay behavior becomes explicit rather than incidental
- lifecycle bugs become less likely because long-lived stores own the stream, not transient widget subtrees

### 7.4 Provisioning target state

Provisioning already has the right trust split, but it should be made more explicit as a state machine:

1. BLE Wi-Fi bootstrap
2. device joins LAN
3. app registers device with API
4. app delivers MQTT credentials locally
5. device reboots and authenticates to broker
6. server confirms announce/online
7. app finalizes naming and placement

Future improvements should formalize this state machine across firmware, API, and app so retries and partial failures are easier to recover.

### 7.5 OTA target state

The ideal OTA architecture should add:

- server-owned OTA manifest/version metadata
- explicit app/API endpoints to request an OTA for authorized devices
- command/status tracking surfaced through app realtime
- artifact lifecycle discipline for hosted firmware binaries

The device-side OTA implementation is already present. The missing piece is the operator and app-facing orchestration layer.

### 7.6 Overall target architecture

The intended end state is:

- firmware remains a clean MQTT-speaking edge runtime
- the server remains the only ownership and auth boundary for the app
- PostgreSQL/TimescaleDB remains canonical for history and durable state
- Redis remains a cache/transient helper, not a source of truth
- app realtime remains server-owned and durable
- Riverpod owns live state outside widget lifecycles

In short:

```text
Firmware -> MQTT -> API ingestion -> canonical persistence -> app realtime gateway -> Riverpod domain stores -> UI
```

That is the architecture the system should continue to converge toward.
