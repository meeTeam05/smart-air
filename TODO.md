# Todo

Checkbox states:

- `[ ]` not started
- `[/]` in progress ← mark when you begin, one at a time
- `[x]` complete ← mark only after verification passes
- `[-]` skipped / won't do (add reason inline)

---

## Active

## Phase 1 — Foundation (Cloud Infrastructure)

> Goal: Docker stack running on Raspberry Pi, accessible via domain, MQTT reachable from ESP32.
> Skills: `terminal-ops`, `safety-guard`, `git-workflow`

### 1.1 Server Setup

- [x] Cài Docker + Docker Compose trên Raspberry Pi 4
- [x] Tạo thư mục `server/` ở root repo với `docker-compose.yml`
- [x] Viết `docker-compose.yml`: nginx, emqx, api (placeholder), postgres, redis, grafana, pgadmin, portainer
- [-] Cấu hình Cloudflare Tunnel → trỏ domain về Pi
  - Hoãn: chưa có domain. Giải pháp tạm: dùng local IP `192.168.1.16`
  - Khi có VPS/domain: migrate docker-compose.yml lên, bật cloudflared
- [x] Xác minh: `curl http://192.168.1.16/api/health` → 200 OK ✓ (local)

### 1.2 EMQX MQTT Broker

- [x] Cấu hình EMQX: enable TLS port 8883 với self-signed cert (dev) / Let's Encrypt (prod)
- [x] Cấu hình EMQX: enable WebSocket port 8083 (cho Flutter MQTT/WSS)
- [x] Cấu hình EMQX: tắt anonymous access, bật per-device auth (username = deviceId, password = secret_key)
- [x] Tạo EMQX ACL rules: mỗi device chỉ pub/sub topic `device/{own_id}/*`
  - `no_match = deny` + per-device allow rules via EMQX HTTP API (18083)
  - Phase 3.4: tự động tạo user + ACL khi device register qua `POST /api/devices`
- [x] Test: kết nối MQTT từ máy dev, verify TLS + auth + ACL (mosquitto_pub/sub QoS 1)

### 1.3 PostgreSQL + TimescaleDB

- [x] Viết `server/db/migrations/001_initial_schema.sql` — toàn bộ schema theo ARCHITECTURE.md
- [x] Chạy migration lên postgres container
- [x] Verify: `\dt` trong psql hiển thị đủ 13 tables ✓
- [x] Enable TimescaleDB extension, tạo hypertable cho `telemetry`, set retention 1 year ✓
- [x] Seed: tạo 1 `device_types` row cho smart-air v1 ✓ (smart_air_v1 / Smart Air v1)

### 1.4 Redis

- [x] Verify Redis container chạy, test `PING` → `PONG` ✓
- [x] Thiết lập Redis password (production) ✓ (set trong .env)
- [x] Document Redis key schema trong `knowledge/wiki/server/redis-schema.md` ✓

---

## Phase 2 — Firmware Foundation

> Goal: ESP32 boot, kết nối WiFi qua BLE provisioning, publish telemetry lên cloud MQTT.
> Skills: `esp32s3/esp32s3-component`, `esp32s3-error`, `esp32s3-freertos`, `esp32s3-i2c`, `esp32s3-nvs`

### 2.1 NVS + Config

- [x] Implement `components/config/` — Kconfig schema cho: WiFi SSID/pass, MQTT broker URL, device secret_key, device ID
- [x] Implement NVS read/write API: `config_get_wifi_creds()`, `config_set_wifi_creds()`, `config_get_mqtt_creds()`
- [x] Unit test: `config_self_test()` guarded by `SA_CONFIG_SELF_TEST=y` — write→read roundtrip, verify, erase
- [x] Đảm bảo không có credential nào hardcoded (SEC-01) — all Kconfig defaults = ""
- Build verified: `smart-air.bin` 0xe3fa0 bytes (11% free on 1 MB app partition) ✓

### 2.2 I2C Bus + Sensors

- [x] Implement `components/drivers/i2c_bus/` — `i2c_master_bus_handle_t` shared init (400 kHz)
- [x] Implement `components/drivers/i2c_devices/sht3x/` — one-shot measurement, `sht3x_read()` → `{temp_c, humidity_pct}`
- [x] Implement `components/drivers/i2c_devices/ds3231/` — `ds3231_get_time()` → `struct tm`
- [x] Skill: load `esp32s3-i2c.md` trước khi viết bất kỳ dòng I2C nào
- [ ] Test: đọc SHT3x trả về nhiệt độ hợp lý (15–45°C), DS3231 trả về timestamp đúng
  - SHT3x + DS3231 init thành công (GPIO8 SDA / GPIO9 SCL, 400 kHz) ✓
  - Chưa verify giá trị đo — cần read call thực tế (Phase 2.6 sensor_task)

### 2.3 SPI Bus + Display

- [ ] Implement `components/drivers/spi_bus/` — SPI2_HOST init
- [ ] Implement `components/drivers/spi_devices/st7789/` — init, `st7789_fill_rect()`, `st7789_draw_string()`
- [ ] Implement `components/drivers/spi_devices/xpt2046/` — `xpt2046_read_touch()` → `{x, y, pressed}`
- [ ] XPT2046 dùng device handle riêng 2 MHz — KHÔNG dùng handle của ST7789 (HW-02)
- [ ] Test: hiển thị "Hello smart-air" lên màn hình, chạm nhận tọa độ đúng

### 2.4 WiFi + BLE Provisioning

- [x] Implement `components/drivers/general/wifi/` — event-driven station mode, EventGroup IP bit
- [x] "Connected" = `IP_EVENT_STA_GOT_IP` — KHÔNG dùng `WIFI_EVENT_STA_CONNECTED` (ADR-003)
- [x] Implement `components/drivers/general/ble_prov/` — GATT server, characteristics 0xFF01/02/03
- [x] BLE prov flow: nhận SSID/pass → gọi `wifi_connect()` → nhận IP → notify JSON → `ble_prov_stop()`
- [x] Lưu credentials vào NVS sau khi provisioning thành công
- [x] Test: end-to-end provisioning thành công qua Flutter app ✓
  - Device advertising as `SMART_AIR_13ED8C` ✓
  - App nhận `{"ip":"192.168.1.26","status":"ok"}` ✓

### 2.5 MQTT Client (TLS)

- [x] Implement `components/drivers/general/mqtt/` — esp_mqtt_client, TLS với embedded CA cert
- [x] Cấu hình LWT: `device/{id}/status` = `{"online":false}` khi disconnect
- [x] Subscribe: `device/{id}/command`, `device/{id}/shadow/get_response`, `device/{id}/ota/update`
- [x] Publish sau khi `IP_EVENT_STA_GOT_IP`: connect MQTT → subscribe → publish `status` online
- [x] Đảm bảo copy event data từ mqtt_event_t trước khi handler return (FW-04) ✓
- [x] Test: thấy message trên EMQX Dashboard khi ESP32 connect ✓
  - Connected với client_id=MAC, broker=mqtts://192.168.1.16:8883 ✓
  - Published `device/dc:b4:d9:13:ed:8c/status` = `{"online":true,...}` ✓
  - Subscribed command / shadow / ota topics ✓

### 2.6 Sensor Task + Telemetry

- [x] Implement `sensor_task` (Core 1, Priority 5, 4096B): poll SHT3x + DS3231 mỗi 5 s
- [x] Implement `mqtt_task` (Core 1, Priority 6, 6144B): nhận data từ queue, publish `telemetry`
- [x] Telemetry payload: `{"device_id":"…","ts":1234567890,"temperature":28.5,"humidity":65.2}`
- [-] Test: thấy telemetry message liên tục trên EMQX, interval ~5 s

### 2.7 SD Card Logging

- [ ] Implement `components/drivers/sdmmc/` — SDIO 4-bit mode init
- [ ] Implement `sd_log_task` (Core 0, Priority 2, 4096B): ghi CSV hàng 30 s
- [ ] CSV format: `timestamp,temperature,humidity`
- [ ] Test: mount SD card, ghi 10 entries, đọc lại bằng `cat` qua USB serial

### 2.8 HTTP Server + mDNS

- [x] Implement `components/httpd/` — GET /api/info + POST /api/config
- [x] Endpoint `GET /api/info` → `{"device_id":"…","firmware":"1.0.0","ip":"…"}`
- [x] Endpoint `POST /api/config` → nhận JSON, ghi NVS
- [-] mDNS: advertise `smart-air.local` — bỏ qua: ESP-IDF v5.4.2 không có mdns.h built-in, dùng IP trực tiếp
- [x] Security: validate Content-Type, reject oversized body (SEC-01 style defense)
- [x] Test: `curl http://192.168.1.26/api/info` → `{"device_id":"dc:b4:d9:13:ed:8c","firmware":"1.0.0","ip":"192.168.1.26"}` ✓

### 2.9 OTA Firmware Update

- [x] Implement `components/ota/` — esp_https_ota với embedded CA cert
- [x] Subscribe `device/{id}/ota/update` → parse URL + SHA256 hash
- [x] Publish progress % lên `device/{id}/ota/progress` mỗi 10%
- [x] Validation task: sau reboot, confirm firmware functional trước `esp_ota_mark_app_valid()`
- [x] Rollback: bootloader tự rollback về factory khi firmware không validate (CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE=y)
- [x] OTA chỉ qua HTTPS — plain HTTP rejected tại ota_trigger() (SEC-02, SEC-03)
- [x] Test: flash firmware mới qua OTA, verify rollback ✓, verify validated ✓
  - Download ~1.2 MB từ https://192.168.1.16/ota/smart-air.bin → ota_0 ✓
  - Reboot vào ota_0, `I ota: OTA validated — new firmware committed` ✓
  - Unvalidated firmware → bootloader rollback về factory ✓

---

## Phase 3 — Core API

> Goal: REST API đầy đủ cho Auth, Homes, Devices, Commands.
> Skills: `api-design`, `backend-patterns`, `security-review`

### 3.1 API Project Setup

- [x] Khởi tạo `server/api/` — Node.js + Fastify plain JS
- [x] Thêm dependencies: fastify, @fastify/jwt, @fastify/cors, @fastify/rate-limit, @fastify/cookie, ioredis, pg, mqtt, bcryptjs, uuid, fastify-plugin
- [x] Cấu hình environment variables (`.env.example` committed, `.env` gitignored)
- [x] Health endpoint `GET /api/health` → 200 ✓
- [x] Migration runner tự động (`scripts/migrate.js`, `npm run migrate`) ✓
- [x] Device ID schema: MAC string (TEXT) thay UUID — `002_device_id_text.sql` idempotent ✓

### 3.2 Authentication

- [x] Implement `POST /api/auth/register` — bcrypt hash (rounds=12)
- [x] Implement `POST /api/auth/login` — verify password, issue JWT access (15 min) + refresh (30 d, HttpOnly cookie)
- [x] Implement `POST /api/auth/refresh` — verify refresh token in DB+Redis, rotate
- [x] Implement `POST /api/auth/logout` — invalidate refresh token in DB+Redis
- [x] Implement JWT middleware — `fastify.authenticate` preHandler trên mọi protected route
- [x] Rate limit: `/api/auth/register|login|refresh` — max 10 req/min per IP
- [x] Test: register → login → access token → gọi protected route → 200 ✓

### 3.3 Homes + Rooms + Members

- [x] CRUD `GET/POST /api/homes`, `PUT/DELETE /api/homes/:id`
- [x] `POST /api/homes/:id/invite` — thêm member bằng email
- [x] CRUD `GET/POST /api/homes/:homeId/rooms`, `PUT/DELETE /api/rooms/:id`
- [x] Middleware: `requireRole()` — chỉ owner/admin mới xóa được home/room
- [x] Test: tạo home → tạo room → invite member → member xem được ✓

### 3.4 Device Registration + Management

- [x] `POST /api/devices` — tạo device với MAC làm ID, sinh `secret_key` (UUID v4)
- [x] `GET /api/devices` — trả về devices thuộc user's homes
- [x] `PUT /api/devices/:id` — đổi tên, chuyển phòng
- [x] `DELETE /api/devices/:id` — xóa device + shadow + pending_cmds + EMQX user
- [x] Sau khi tạo device: gọi EMQX REST API tạo MQTT user + ACL rule (`device/{id}/#`)
- [x] Test: tạo device → GET list → thấy device ✓
  - `normalizeDeviceId()` — lowercase MAC để nhất quán ✓

### 3.5 MQTT Bridge Service

- [x] `src/plugins/mqtt.js` — kết nối `mqtt://emqx:1883` internal (không TLS) as `sa-server`
- [x] Subscribe `device/+/status` → UPDATE `devices.online`, `last_seen`
- [x] Subscribe `device/+/telemetry` → INSERT vào `telemetry` hypertable
- [x] Subscribe `device/+/response` → UPDATE `commands.status`, `executed_at`
- [x] Subscribe `device/+/shadow/report` → update Redis shadow + DB backup
- [x] Subscribe `device/+/ota/progress` → SET Redis `ota_progress:{deviceId}` TTL 10m
- [x] On status online=true: flush `pending_cmds` + push `shadow/get_response`
- [x] Test: ESP32 publish telemetry → row trong TimescaleDB ✓

### 3.6 Device Shadow API

- [x] `GET /api/devices/:id/shadow` → Redis cache, fallback `device_shadows` table
- [x] `PUT /api/devices/:id/shadow/desired` → set desired in Redis+DB, push to device if online
- [x] `src/services/shadow.js` — Redis key `shadow:{deviceId}`, TTL 1h
- [x] Khi device online: gửi `shadow/get_response` với `desired` hiện tại
- [x] Firmware: sensor_task publish `device/{id}/shadow/report` sau mỗi lần đo ✓
- [x] Test: shadow/report từ firmware → GET /api/devices/:id/shadow thấy reported ✓

### 3.7 Command API + Queue

- [x] `POST /api/devices/:id/command` — body `{payload:{…}}`
- [x] Device online: publish MQTT command ngay, status = `sent`
- [x] Device offline: RPUSH `pending_cmds:{deviceId}`, flush khi online
- [x] `GET /api/devices/:id/commands` — lịch sử lệnh (paginated, limit/offset)
- [x] Firmware: parse `command_id` từ payload, publish `device/{id}/response` với `{"command_id":"…","status":"done"}` ✓
- [x] Test: POST command → `sent` → firmware ack → `executed_at` set ✓
  - Verified: `command_id` returned, status=`sent`, history API hoạt động ✓

### 3.8 Telemetry API

- [x] `GET /api/devices/:id/telemetry?from=&to=&limit=` — query TimescaleDB
- [x] `?agg=1h` → `time_bucket($interval, ts)` + AVG temperature/humidity
- [x] Defaults: from=NOW()-24h, to=NOW(), limit=1000, max=5000
- [x] Test: query 24h telemetry → trả về đúng số điểm ✓

---

## Phase 4 — Flutter App

> Goal: App hoàn chỉnh với BLE provisioning, quản lý device, realtime dashboard.
> Skills: `dart-flutter-patterns`, `flutter-dart-code-review`, `ui-ux-pro-max`

### 4.1 App Architecture Setup

- [x] Thiết lập BLoC / Riverpod (chọn 1, document trong DECISIONS.md)
- [x] Thiết lập GoRouter cho navigation
- [x] Thiết lập Dio với interceptors: JWT auto-refresh, error handling
- [x] Thiết lập Freezed cho model classes
- [x] Thiết lập `AppPalette` theme + `context.colors` extension
- [x] Cấu hình `flutter_secure_storage` cho JWT tokens

### 4.2 Authentication Flow

- [x] Screen: Login (email/password) → POST `/api/auth/login` → store tokens
- [x] Screen: Register → POST `/api/auth/register`
- [x] Auto-refresh: Dio interceptor — khi 401, gọi `/api/auth/refresh`, retry request
- [x] Screen: Logout → POST `/api/auth/logout` → clear tokens → redirect login
- [ ] Test: login → app state logged in → logout → redirect

### 4.3 Home + Room Management

- [x] Screen: Home list (`GET /api/homes`)
- [x] Screen: Create home (form → `POST /api/homes`)
- [-] Screen: Room list trong home — home_detail_screen hiển thị devices trực tiếp, bỏ qua tầng room
- [-] Screen: Create room — không implement, device gắn thẳng vào home
- [x] Screen: Invite member (nhập email → `POST /api/homes/:id/invite`)
- [ ] Test: create home → invite → member thấy home

### 4.4 BLE Provisioning Flow

- [x] Xin BLE permission (Android: BLUETOOTH_SCAN, BLUETOOTH_CONNECT; iOS: NSBluetoothAlwaysUsageDescription)
- [x] Screen: Scan BLE devices → hiển thị list
- [x] Connect GATT → subscribe 0xFF03 → write SSID/pass
- [x] Hiển thị progress spinner trong khi chờ notify
- [x] Nhận `{"ip":"…","status":"ok"}` → gọi `POST /api/devices` → navigate to device detail
- [x] Error handling: timeout 30 s, BLE disconnect, wrong credentials
- [ ] Test: provision real device, app navigate đến device detail screen

### 4.5 Device Dashboard (Realtime)

- [x] Connect MQTT over WSS: `wss://yourdomain.com/ws` với JWT auth
- [x] Subscribe `device/{id}/status` → update online indicator trong real-time
- [x] Subscribe `device/{id}/telemetry` → update temperature/humidity display
- [x] Screen: Device detail — hiển thị realtime temp, humidity, online status, last seen
- [ ] Test: ESP32 publish telemetry → Flutter nhận và hiển thị trong < 2 s

### 4.6 Command + Control

- [x] UI: Toggle switch/button → `POST /api/devices/:id/command`
- [x] Hiển thị trạng thái: pending → sent → done/failed
- [x] Hiển thị thông báo khi device offline: "Command queued"
- [x] Screen: Command history (`GET /api/devices/:id/commands`)
- [ ] Test: gửi command online → response nhận → trạng thái cập nhật

### 4.7 Telemetry Chart

- [x] Dependency: `fl_chart`
- [x] Screen: Telemetry chart — line chart temperature + humidity theo thời gian
- [x] Date range picker: 1h / 24h / 7d
- [x] Fetch `GET /api/devices/:id/telemetry?from=&to=`
- [ ] Test: chart hiển thị đúng số điểm, đúng values

### 4.8 Push Notifications

- [ ] Tích hợp Firebase Cloud Messaging (FCM)
- [ ] Đăng ký FCM token sau login: `POST /api/users/me/fcm-token`
- [ ] Xử lý notification khi app foreground (in-app banner) và background (system notification)
- [ ] Test: API trigger notification → thiết bị nhận

---

## Phase 5 — Advanced Features

> Goal: Automation engine, push notifications from rules, OTA trigger từ app.
> Skills: `api-design`, `security-review`

### 5.1 Automation Engine

- [ ] `POST /api/automations` — tạo rule (trigger + action)
- [ ] Trigger type `telemetry`: khi MQTT message đến `device/+/telemetry`, evaluate conditions
- [ ] Trigger type `schedule`: cron job (node-cron), eval lúc scheduled time
- [ ] Action: `POST /api/devices/:id/command` (qua internal call)
- [ ] `PATCH /api/automations/:id/toggle` — bật/tắt rule
- [ ] Test: tạo rule "nhiệt độ > 30°C → bật quạt" → ESP32 đạt ngưỡng → command gửi tự động

### 5.2 Alert Notifications

- [ ] Khi automation trigger: tạo `notifications` row + gửi FCM push qua `notification.service.js`
- [ ] Khi command done/failed: notify user
- [ ] Khi device offline (LWT): notify owner
- [ ] `GET /api/notifications` — danh sách thông báo (unread first)
- [ ] App screen: Notification list, mark as read
- [ ] Test: automation trigger → push nhận trên điện thoại

### 5.3 OTA Trigger từ App

- [ ] Upload firmware binary lên server: `POST /api/ota/upload` → lưu file, sinh URL
- [ ] App UI: "Update Firmware" button → `POST /api/devices/:id/ota`
- [ ] API publish `device/{id}/ota/update` với URL + SHA256
- [ ] App nhận OTA progress qua WebSocket → hiển thị progress bar
- [ ] Test: upload firmware → trigger OTA → progress bar → device reboot với firmware mới

### 5.4 Grafana Monitoring

- [ ] Kết nối Grafana với PostgreSQL datasource (TimescaleDB)
- [ ] Tạo dashboard: temperature, humidity theo thời gian, by device
- [ ] Panel: device online/offline count
- [ ] Panel: API request rate, error rate
- [ ] Expose `/grafana` qua Nginx (auth protected)

---

## Phase 6 — Production Hardening

> Goal: Bảo mật, monitoring, backup, deploy lên VPS.
> Skills: `security-review`, `security-scan`, `verification-loop`

### 6.1 Security Audit

- [ ] Chạy `security-review` agent trên toàn bộ API routes
- [ ] Verify: không có credential hardcoded (grep toàn repo)
- [ ] Verify: tất cả endpoints có authentication (trừ `/api/auth/*`, `/api/health`)
- [ ] Verify: rate limiting active trên auth endpoints
- [ ] Verify: SQL injection không thể xảy ra (parameterized queries)
- [ ] Verify: MQTT ACL — device chỉ pub/sub topic của chính nó
- [ ] Kiểm tra SEC-01 / SEC-02 / SEC-03 theo CONSTRAINTS.md

### 6.2 ESP32 Security

- [ ] Verify: MQTT kết nối qua TLS 8883 — không dùng 1883 (plain)
- [ ] Verify: OTA chỉ HTTPS, CA cert embedded
- [ ] Verify: secret_key không in ra log (`ESP_LOGI` bị cấm với sensitive data)
- [ ] Verify: webserver validate input, reject oversized body

### 6.3 Backup + Reliability

- [ ] Script `server/scripts/backup.sh` — pg_dump + copy sang remote storage mỗi ngày
- [ ] Setup cron job backup trên Pi
- [ ] Docker health checks cho tất cả services
- [ ] Nginx: enable gzip, set security headers (X-Frame-Options, HSTS)
- [ ] Test: stop postgres container → start lại → data còn đủ

### 6.4 Migrate lên VPS

- [ ] Provision VPS Hetzner CPX11 (~$4/tháng)
- [ ] Copy `docker-compose.yml` + `.env` lên VPS
- [ ] pg_dump từ Pi → restore lên VPS postgres
- [ ] Update Cloudflare Tunnel target → VPS IP
- [ ] Smoke test: Flutter app kết nối VPS → telemetry chạy
- [ ] Shutdown Pi dev server

---

## Completed

### Task: Deploy Obsidian RAG + Claude Code knowledge architecture — 2026-04-08

- [x] Rewrite knowledge/wiki/\_master-index.md in clean English
- [x] Create firmware wiki: \_index, esp-idf-api, freertos-patterns, drivers-i2c, drivers-spi, network-wifi, network-mqtt, network-http, ota
- [x] Create hardware wiki: \_index, component-map, kicad-notes, power
- [x] Create app wiki: \_index, flutter-patterns, ui-palette
- [x] Create research wiki: \_index
- [x] Migrate tasks/knowledge.md stable facts into wiki — reset to short-term scratchpad
- [x] Remove KNOWGRAPH section and update Skills table in CLAUDE.md
- [x] Remove KNOWGRAPH tasks from .vscode/tasks.json

### Task: Replace `.clang-format` with ESP-IDF-appropriate style — 2026-03-18

- [x] Research ESP-IDF formatting conventions and popular ESP32 projects
- [x] Write the new `.clang-format` at the project root
- [x] Verified with clang-format v22: config parses, formats `main.c` with correct 4-space indent
- [x] Updated `tasks/knowledge.md` with ESP-IDF formatting findings

### Task: Prune ai/ agents and skills to project-relevant set — 2026-04-13

- [x] Removed 24 irrelevant agents (Go, Java, Kotlin, Rust, Python, GAN, healthcare, SEO, etc.)
- [x] Reduced skills from 187 → 34 (kept esp32s3, dart-flutter, cpp, security, git, arch, ai-infra)
- [x] Updated AGENTS.md with full agent + skill reference tables and correct `ai/` paths

---

## See also

- [[review]] — What was done in completed tasks
- [[CHANGELOG]] — Public-facing record of shipped work

### Task: Deploy Obsidian RAG + Claude Code knowledge architecture — 2026-04-08

- [x] Rewrite knowledge/wiki/\_master-index.md in clean English
- [x] Create firmware wiki: \_index, esp-idf-api, freertos-patterns, drivers-i2c, drivers-spi, network-wifi, network-mqtt, network-http, ota
- [x] Create hardware wiki: \_index, component-map, kicad-notes, power
- [x] Create app wiki: \_index, flutter-patterns, ui-palette
- [x] Create research wiki: \_index
- [x] Migrate tasks/knowledge.md stable facts into wiki — reset to short-term scratchpad
- [x] Remove KNOWGRAPH section and update Skills table in CLAUDE.md
- [x] Remove KNOWGRAPH tasks from .vscode/tasks.json

### Task: Replace `.clang-format` with ESP-IDF-appropriate style — 2026-03-18

- [x] Research ESP-IDF formatting conventions and popular ESP32 projects
- [x] Write the new `.clang-format` at the project root
  - Base: Google style (4-space, spaces only, column 120)
  - Allman brace wrapping for functions, K&R for control flow
  - Removed all Linux Kernel `ForEachMacros` (700+ lines) — replaced with 7 FreeRTOS macros
  - Added project comment block at top
- [x] Verified with clang-format v22: config parses, formats `main.c` with correct 4-space indent
- [x] Updated `tasks/knowledge.md` with ESP-IDF formatting findings
- [x] Updated `tasks/session.md`

---

## See also

- [[review]] — What was done in completed tasks
- [[CHANGELOG]] — Public-facing record of shipped work
