# MQTT_PROTOCOL.md — smart-air Integration Contract

> Đây là **nguồn sự thật duy nhất** về giao tiếp MQTT giữa ESP32 và Cloud.
> Firmware và API đều phải tuân theo file này. Không được tự ý thay đổi field name, topic, hay format mà không cập nhật file này trước.

---

## 1. Thông tin kết nối

| Thông số         | Giá trị |
| ---------------- | ------ |
| Broker ESP32     | `wss://minhnhat05.xyz/mqtt` qua Cloudflare Tunnel -> `nginx` -> `emqx:8083` |
| Broker nội bộ API| `emqx:1883` trong Docker network |
| Flutter WSS path | `wss://minhnhat05.xyz/mqtt` qua `nginx -> emqx:8083` |
| Port ESP32       | Public `443` qua WSS; `8883` chỉ là direct override khi có TCP public |
| Port WSS nội bộ  | `8083` (không expose trực tiếp ra host) |
| TLS              | Bắt buộc cho device qua `wss://` hoặc direct `mqtts://`; plain `1883` chỉ dùng nội bộ Docker |
| Auth device      | `username = deviceId`, `password = secret_key` |
| Auth bridge      | `username = sa-server`, `password = EMQX_MQTT_PASSWORD` |
| QoS mặc định     | 1 (at least once) |
| Keep-alive       | 60 giây |

> `secret_key` chỉ được backend cấp khi app gọi `POST /api/devices`.
> Thiết bị chưa đăng ký chưa có quyền đăng nhập MQTT broker.

---

## 2. Topic Map

```
Direction: ESP32 → Broker   ký hiệu: →
Direction: Broker → ESP32   ký hiệu: ←
```

| Topic                              | Direction | QoS | Retain | Mô tả                        |
| ---------------------------------- | --------- | --- | ------ | ---------------------------- |
| `device/{deviceId}/status`         | →         | 1   | true   | Online/offline heartbeat + LWT |
| `device/{deviceId}/telemetry`      | →         | 1   | false  | Sensor data mỗi `SA_SENSOR_POLLING_INTERVAL` giây |
| `device/{deviceId}/command`        | ←         | 1   | false  | Lệnh điều khiển từ app       |
| `device/{deviceId}/response`       | →         | 1   | false  | Kết quả thực thi lệnh        |
| `device/{deviceId}/shadow/report`  | →         | 1   | false  | Device báo trạng thái hiện tại |
| `device/{deviceId}/shadow/get`     | →         | 1   | false  | Device xin desired state khi boot |
| `device/{deviceId}/shadow/get_response` | ←    | 1   | false  | Server trả về desired state  |
| `device/{deviceId}/ota/update`     | ←         | 1   | false  | Trigger OTA                  |
| `device/{deviceId}/ota/progress`   | →         | 1   | false  | Tiến trình OTA               |

> `{deviceId}` là MAC lowercase của ESP32, ví dụ: `dc:b4:d9:13:ed:8c`.
> Per-device user và ACL được tạo bởi API server trong EMQX built-in database, không thêm thủ công trong dashboard cho flow bình thường.

---

## 3. Payload Schema chi tiết

### 3.1 `device/{id}/status` — Online/Offline

**Publish khi connect (online):**
```json
{
  "online": true,
  "firmware": "1.0.3",
  "ip": "192.168.1.42",
  "ts": 1712345678
}
```

**LWT — Last Will Testament (offline):**
```json
{
  "online": false,
  "ts": 1712345678
}
```

> ESP32 cấu hình LWT message này khi khởi tạo MQTT client. Broker tự publish khi device mất kết nối đột ngột.
> `retain = true` để Flutter app nhận được trạng thái ngay khi subscribe.
> Server chỉ xử lý payload là JSON object có `online` boolean; payload sai schema được ACK và bỏ qua.

---

### 3.2 `device/{id}/telemetry` — Sensor Data

```json
{
  "device_id": "dc:b4:d9:13:ed:8c",
  "mode": "on",
  "ts": 1712345678,
  "temperature": 28.5,
  "humidity": 65.2,
  "co_ppm": 12.3,
  "no2_ppm": 0.4
}
```

| Field        | Type           | Unit | Ghi chú                                                  |
| ------------ | -------------- | ---- | -------------------------------------------------------- |
| `device_id`  | string         | —    | MAC string, trùng với topic                              |
| `mode`       | string         | —    | `"on"` hoặc `"off"` — trạng thái device mode             |
| `ts`         | integer        | —    | Unix timestamp, giây (không phải ms)                     |
| `temperature`| float \| null  | °C   | null khi SA_ENABLE_SHT3X=n hoặc đọc lỗi hoặc mode=off   |
| `humidity`   | float \| null  | %RH  | null khi SA_ENABLE_SHT3X=n hoặc đọc lỗi hoặc mode=off   |
| `co_ppm`     | float \| null  | ppm  | null khi SA_ENABLE_CO_SENSOR=n hoặc chưa calibrate hoặc mode=off |
| `no2_ppm`    | float \| null  | ppm  | null khi SA_ENABLE_NO2_SENSOR=n hoặc chưa calibrate hoặc mode=off |

> Publish mỗi SA_SENSOR_POLLING_INTERVAL s từ `sensor_task`.
> Khi `mode="off"`: sensor gate tắt; firmware publish final null telemetry khi chuyển OFF, sensor task dừng publish cho đến khi ON lại.
> Khi `CONFIG_SA_DEMO_NO_PERIPHERALS=y`: firmware publish các field sensor từ mảng dữ liệu ảo nội bộ, vẫn giữ nguyên JSON schema và topics hiện tại.
> Server INSERT vào TimescaleDB hypertable `telemetry` (JSON blob — field mới tự xuất hiện).

---

### 3.3 `device/{id}/command` — Lệnh điều khiển

Firmware đăng ký command handlers qua `mqtt_register_command_handler(type, callback)` trong `sysload.c`.
Server publish command dưới dạng `{ "command_id": "...", "type": "...", ... }`.
Generic REST command chỉ nhận `relay_set`, `device_mode`, `set_time`, `calibrate_co`, `calibrate_no2`.
`set_config` không được server gửi qua generic command vì đổi credential firmware; OTA dùng topic riêng `device/{id}/ota/update`, không dùng `ota_update` trên command topic.
Firmware phải trả `{"status":"error"}` cho command thiếu `type`, thiếu field bắt buộc, hoặc không có handler trong build hiện tại. `relay_set` được ACK `done` trong cả normal mode và demo mode khi build bật `CONFIG_SA_ENABLE_RELAYS=y`; nếu relay feature bị tắt trong build thì firmware vẫn trả `error`.

#### 3.3.1 Command: `relay_set`

Điều khiển relay channel (1–3).

**Payload:**
```json
{
  "command_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "relay_set",
  "relay": 1,
  "state": true
}
```

| Field   | Type    | Ghi chú                                              |
| ------- | ------- | ---------------------------------------------------- |
| `type`  | string  | `"relay_set"`                                       |
| `relay` | integer | Channel number: 1, 2, hoặc 3                         |
| `state` | boolean | `true` = bật relay, `false` = tắt relay              |

**Validation:**
- `relay` phải là integer trong khoảng 1–3
- `state` phải là boolean
- Lệnh bị reject với `ESP_ERR_INVALID_STATE` nếu device mode = off

**Side effects:**
- GPIO output thay đổi (active-high)
- NVS persist state mới
- Buzzer beep 50 ms
- Publish shadow delta: `{"mode":"on","relay_N":<bool>,"ts":...}` lên `device/{id}/shadow/report`

#### 3.3.2 Command: `device_mode`

Bật/tắt toàn bộ thiết bị (sensor + relay).

**Payload:**
```json
{
  "command_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "device_mode",
  "mode": "on"
}
```

| Field  | Type   | Ghi chú                                              |
| ------ | ------ | ---------------------------------------------------- |
| `type` | string | `"device_mode"`                                      |
| `mode` | string | `"on"` hoặc `"off"`                                  |

**Validation:**
- `mode` phải là string `"on"` hoặc `"off"`

**Side effects khi chuyển sang OFF:**
1. Disable sensor gate (`sensor_task_set_enabled(false)`)
2. Publish final null telemetry: `{"device_id":"...","mode":"off","ts":...,"temperature":null,...}`
3. Force tất cả relay OFF (`relay_force_all_off()`)
4. Publish mode-off shadow: `{"mode":"off","relay_1":false,"relay_2":false,"relay_3":false,"temperature":null,...}`
5. Persist mode=0 vào NVS

**Side effects khi chuyển sang ON:**
1. Persist mode=1 vào NVS
2. Enable sensor gate (`sensor_task_set_enabled(true)`)
3. Publish mode-on shadow với relay states hiện tại: `{"mode":"on","relay_1":<bool>,"relay_2":<bool>,"relay_3":<bool>,"ts":...}`

#### 3.3.3 Command: `set_time`

```json
{
  "command_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "set_time",
  "ts": 1777631761
}
```

`ts` là Unix timestamp theo giây, không phải milliseconds.

#### 3.3.4 Command: `calibrate_co` / `calibrate_no2`

```json
{
  "command_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "calibrate_co"
}
```

Không có field phụ. Firmware chạy calibration sensor tương ứng và publish response `done|error`.

---

### 3.4 `device/{id}/response` — Kết quả lệnh

Firmware publish response sau khi command thực sự hoàn tất. Handler ngắn có thể ACK ngay trong MQTT callback; handler dài có thể defer sang worker task rồi ACK sau. `status` vẫn map theo kết quả cuối cùng:
- `ESP_OK` → `"status":"done"`
- `ESP_ERR_NOT_FINISHED` → handler đã nhận command và sẽ publish response cuối cùng bất đồng bộ
- lỗi khác `ESP_OK` → `"status":"error"`
- command type không hỗ trợ trong build hiện tại → `"status":"error"`

**Ví dụ response thành công:**
```json
{
  "command_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "done"
}
```

**Ví dụ response lỗi:**
```json
{
  "command_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "error"
}
```

---

### 3.5 `device/{id}/shadow/report` — Device báo trạng thái

Firmware publish shadow report từ 3 nguồn:

1. **Sensor task** (mỗi SA_SENSOR_POLLING_INTERVAL s):
```json
{
  "mode": "on",
  "temperature": 28.5,
  "humidity": 65.2,
  "co_ppm": 12.3,
  "no2_ppm": 0.4,
  "ts": 1712345678
}
```

2. **Relay delta** (sau `relay_set` thành công):
```json
{
  "mode": "on",
  "relay_1": true,
  "ts": 1712345678
}
```

3. **Device mode change** (sau `device_mode` command):

Mode OFF:
```json
{
  "mode": "off",
  "relay_1": false,
  "relay_2": false,
  "relay_3": false,
  "temperature": null,
  "humidity": null,
  "co_ppm": null,
  "no2_ppm": null,
  "ts": 1712345678
}
```

Mode ON:
```json
{
  "mode": "on",
  "relay_1": false,
  "relay_2": true,
  "relay_3": false,
  "ts": 1712345678
}
```

> Shadow report không có wrapper `{"reported":{...}}` — payload là flat JSON.
> Server merge các shadow reports vào Redis cache + DB backup.

---

### 3.6 `device/{id}/shadow/get` — Xin desired state khi boot

```json
{
  "ts": 1712345678
}
```

> Publish ngay sau khi MQTT connect. Server sẽ trả lời qua `shadow/get_response`.

---

### 3.7 `device/{id}/shadow/get_response` — Server trả về desired

```json
{
  "desired": {
    "power": false,
    "mode": 2
  },
  "delta": {
    "power": false,
    "mode": 2
  },
  "ts": 1712345678
}
```

> `delta` = những field mà `reported` khác `desired`. ESP32 chỉ cần execute delta, không cần apply toàn bộ desired.

---

### 3.8 `device/{id}/ota/update` — Trigger OTA

```json
{
  "url": "https://yourdomain.com/firmware/smart-air-v1.0.4.bin",
  "sha256": "a3f5b2c1d4e6f7890123456789abcdef0123456789abcdef0123456789abcdef",
  "version": "1.0.4",
  "ts": 1712345678
}
```

| Field     | Ghi chú                                                  |
| --------- | -------------------------------------------------------- |
| `url`     | HTTPS only — ESP32 từ chối nếu không có `https://`      |
| `sha256`  | Hash của file binary, verify sau khi download xong      |
| `version` | String, dùng để log và hiển thị trong app               |

---

### 3.9 `device/{id}/ota/progress` — Tiến trình OTA

```json
{
  "status": "downloading",
  "progress": 45,
  "version": "1.0.4",
  "ts": 1712345678
}
```

| `status`      | Khi nào                                      |
| ------------- | -------------------------------------------- |
| `downloading` | Đang download, `progress` = 0–99            |
| `validating`  | Download xong, đang verify SHA256           |
| `rebooting`   | Chuẩn bị reboot với firmware mới            |
| `failed`      | Thất bại, kèm field `reason`                |

---

## 4. Command-Response Flow

> Firmware publish explicit response message lên `device/{id}/response` sau khi thực thi command.

### 4.1 Device ONLINE — xử lý ngay

```
App                   API (Node.js)         EMQX              ESP32
 │                        │                   │                  │
 ├─POST /command──────────→│                   │                  │
 │                        ├─INSERT commands DB │                  │
 │                        ├─publish command───→│─────────────────→│
 │                        │                   │                  ├─parse JSON payload
 │                        │                   │                  ├─execute action (relay_set/device_mode)
 │                        │                   │←─response────────┤ {"command_id":"...","status":"done|error"}
 │                        │←─subscribe response│                  │
 │                        ├─UPDATE command status by response    │
 │                        │                   │←─shadow/report───┤ (state sync side effect)
```

**Verification:** API dùng response topic để xác nhận trạng thái execute (`done|error`); shadow/report vẫn dùng để đồng bộ trạng thái thực tế của thiết bị.

### 4.2 Device OFFLINE — queue lại

```
App                   API / PostgreSQL     EMQX               ESP32
 │                        │                   │                  │
 ├─POST /command──────────→│                   │                  │
 │                        ├─INSERT commands status=pending       │
 │←─201 command_id────────┤                   │                  │
 │                        │                   │    (boot + connect)
 │                        │                   │←─status online───┤
 │                        ├─DB FIFO flush pending commands       │
 │                        ├─UPDATE status=sent │                  │
 │                        ├─COMMIT dispatch    │                  │
 │                        ├─publish command───→│─────────────────→│
 │                        ├─publish fail? → revert status=pending │
 │                        │                   │                  ├─execute
 │                        │                   │←─response────────┤
 │                        ├─UPDATE status done/error             │
```

---

## 5. Idempotency & Retry Rules

> **Ghi chú:** Firmware hiện tại (v1.0) không implement idempotency tracking. Command handlers (`relay_set`, `device_mode`) không track processed commands. Section này mô tả planned behavior cho future versions.

### 5.1 ESP32 phải làm gì khi nhận command (planned)

```
Nhận message trên device/{id}/command
    │
    ├─ Parse JSON, lấy command_id
    │
    ├─ Kiểm tra command_id trong processed_cmds[] (lưu trong RAM, tối đa 20 entries)
    │       │
    │       ├─ ĐÃ xử lý rồi → publish response cũ (status: duplicate_cmd) → bỏ qua
    │       │
    │       └─ CHƯA xử lý → thực thi action (inline hoặc qua worker) → lưu command_id vào processed_cmds[] → publish response
```

> Tại sao cần: MQTT QoS 1 đảm bảo "at least once" — broker có thể gửi lại cùng 1 message nếu không nhận được PUBACK. Không có idempotency, lệnh "bật đèn" có thể chạy 2 lần.

**Current behavior (v1.0):** Command handlers idempotent tại application level (`relay_set` short-circuits khi state không đổi, `device_mode_set` idempotent check), nhưng không track `command_id`.

### 5.2 API retry policy

- API **không tự retry** command đã gửi qua MQTT.
- Nếu timeout: cập nhật status = `timeout`, app hiển thị lỗi, user tự gửi lại nếu muốn.
- Mỗi lần gửi lại = 1 `command_id` mới = 1 lần execute mới (không phải retry cũ).

### 5.3 ESP32 reconnect

- Sau khi reconnect WiFi/MQTT: firmware nên publish `shadow/get` để xin desired state mới nhất.
- Server cũng push desired state khi nhận `status` online=true nếu shadow desired không rỗng.
- Server flush pending commands từ PostgreSQL `commands` khi nhận `status` online=true.
- ESP32 xử lý commands tuần tự (single-threaded MQTT event handler).

---

## 6. Security Rules

- **ACL:** Device chỉ được pub/sub `device/{own_id}/*`. Device A không thể gửi command đến Device B.
- **TLS:** ESP32 mặc định kết nối `wss://minhnhat05.xyz/mqtt` và verify Cloudflare/public cert bằng embedded CA bundle. Direct `mqtts://...:8883` chỉ là override khi có public TCP phù hợp. Không dùng plain 1883.
- **Auth:** Mỗi device có `secret_key` riêng sinh ra lúc đăng ký, lưu trong NVS. Không hardcode.
- **Provisioning order:** App phải gọi `POST /api/devices` trước; backend tạo EMQX user + ACL rồi mới chuyển `secret_key` xuống firmware.
- **Flutter/WSS:** EMQX WebSocket hiện dùng MQTT username/password từ built-in database; JWT REST API chưa được dùng cho MQTT/WSS.

> Kênh app chuyển `secret_key` xuống firmware là local device provisioning, không phải MQTT contract công khai của backend.
> Firmware hiện hỗ trợ `POST http://<device-ip>/api/config` với JSON `{ "device_id": "...", "secret_key": "...", "broker_uri": "wss://minhnhat05.xyz/mqtt" }`; `broker_uri` optional. Nếu bỏ qua, firmware xóa override cũ và dùng Kconfig default. Endpoint này chỉ dùng trước lần MQTT login đầu tiên, validate `device_id` phải trùng MAC thật của ESP32, sau đó firmware lưu NVS và reboot.

### 6.1 Provisioning sequence bắt buộc

```text
1. Flutter lấy device_id từ BLE / local provisioning
2. Flutter gọi POST /api/devices
3. API tạo secret_key + EMQX built-in user + per-device ACL
4. API trả secret_key về app đúng 1 lần
5. App chuyển credential đó xuống ESP32 qua local provisioning endpoint `POST /api/config`
6. ESP32 mới được phép login MQTT qua WSS/TLS (`wss://minhnhat05.xyz/mqtt` mặc định, hoặc `mqtts://...:8883` nếu operator override)
7. Factory reset vật lý phải xóa toàn bộ NVS mặc định của firmware, nên sau reset không được giữ lại `broker_uri`, `secret_key`, `mode`, hay calibration cũ.
```

---

## 7. Ví dụ đầy đủ — Bật relay khi device online

```
1. User bấm nút bật relay 1 trong Flutter app

2. App gọi:
   POST /api/devices/dc:b4:d9:13:ed:8c/command
   Body: { "relay": 1, "state": true }

3. API INSERT command status=`pending`; nếu MQTT bridge ready thì flush ngay từ PostgreSQL

4. API publish MQTT:
   Topic: device/dc:b4:d9:13:ed:8c/command
   Payload: {
     "command_id": "...",
     "type": "relay_set",
     "relay": 1,
     "state": true
   }

5. ESP32 nhận, parse JSON:
   → Gọi handle_relay_set() trong sysload.c
   → relay_set(1, true) thực thi
   → GPIO set high, NVS persist, buzzer beep 50ms
   → Publish shadow delta:
     Topic: device/dc:b4:d9:13:ed:8c/shadow/report
     Payload: { "mode": "on", "relay_1": true, "ts": 1712345679 }

6. API subscribe response:
   → Nhận {command_id,status}
   → UPDATE commands SET status='done|error', executed_at=NOW()

7. API subscribe shadow/report:
   → Nhận shadow delta, UPSERT device_shadows để đồng bộ trạng thái relay thực tế

8. App refresh dữ liệu qua REST hoặc lớp realtime tương lai và hiển thị relay 1 = "bật"
```

---

## 8. Changelog

| Ngày       | Thay đổi                        | Người thay đổi |
| ---------- | ------------------------------- | -------------- |
| 2026-04-13 | Khởi tạo file, version 1.0      | —              |
| 2026-05-11 | Thêm `relay_set` + `device_mode` commands, cập nhật telemetry/shadow với `mode` field | Atlas |
