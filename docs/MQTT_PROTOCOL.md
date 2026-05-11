# MQTT_PROTOCOL.md — smart-air Integration Contract

> Đây là **nguồn sự thật duy nhất** về giao tiếp MQTT giữa ESP32 và Cloud.
> Firmware và API đều phải tuân theo file này. Không được tự ý thay đổi field name, topic, hay format mà không cập nhật file này trước.

---

## 1. Thông tin kết nối

| Thông số        | Giá trị                              |
| --------------- | ------------------------------------ |
| Broker          | `mqtt.yourdomain.com`                |
| Port ESP32      | `8883` (MQTT over TLS)               |
| Port Flutter    | `8083` (MQTT over WebSocket/WSS)     |
| TLS             | Bắt buộc — plain 1883 bị cấm        |
| Auth            | `username = deviceId`, `password = secret_key` |
| QoS mặc định   | 1 (at least once)                    |
| Keep-alive      | 60 giây                              |

---

## 2. Topic Map

```
Direction: ESP32 → Broker   ký hiệu: →
Direction: Broker → ESP32   ký hiệu: ←
```

| Topic                              | Direction | QoS | Retain | Mô tả                        |
| ---------------------------------- | --------- | --- | ------ | ---------------------------- |
| `device/{deviceId}/status`         | →         | 1   | true   | Online/offline heartbeat + LWT |
| `device/{deviceId}/telemetry`      | →         | 1   | false  | Sensor data mỗi 30 giây      |
| `device/{deviceId}/command`        | ←         | 1   | false  | Lệnh điều khiển từ app       |
| `device/{deviceId}/response`       | →         | 1   | false  | Kết quả thực thi lệnh        |
| `device/{deviceId}/shadow/report`  | →         | 1   | false  | Device báo trạng thái hiện tại |
| `device/{deviceId}/shadow/get`     | →         | 1   | false  | Device xin desired state khi boot |
| `device/{deviceId}/shadow/get_response` | ←    | 1   | false  | Server trả về desired state  |
| `device/{deviceId}/ota/update`     | ←         | 1   | false  | Trigger OTA                  |
| `device/{deviceId}/ota/progress`   | →         | 1   | false  | Tiến trình OTA               |

> `{deviceId}` là UUID của device, ví dụ: `550e8400-e29b-41d4-a716-446655440000`

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

---

### 3.2 `device/{id}/telemetry` — Sensor Data

```json
{
  "device_id": "dc:b4:d9:13:ed:8c",
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
| `ts`         | integer        | —    | Unix timestamp, giây (không phải ms)                     |
| `temperature`| float \| null  | °C   | null khi SA_ENABLE_SHT3X=n hoặc đọc lỗi                 |
| `humidity`   | float \| null  | %RH  | null khi SA_ENABLE_SHT3X=n hoặc đọc lỗi                 |
| `co_ppm`     | float \| null  | ppm  | null khi SA_ENABLE_CO_SENSOR=n hoặc chưa calibrate       |
| `no2_ppm`    | float \| null  | ppm  | null khi SA_ENABLE_NO2_SENSOR=n hoặc chưa calibrate      |

> Publish mỗi SA_SENSOR_POLLING_INTERVAL s từ `sensor_task`.
> Server INSERT vào TimescaleDB hypertable `telemetry` (JSON blob — field mới tự xuất hiện).

---

### 3.3 `device/{id}/command` — Lệnh điều khiển

```json
{
  "cmd_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "action": "set_power",
  "value": true,
  "ts": 1712345678
}
```

| Field    | Type    | Ghi chú                                              |
| -------- | ------- | ---------------------------------------------------- |
| `cmd_id` | string  | UUID — dùng để match với response, đảm bảo idempotency |
| `action` | string  | Xem bảng actions bên dưới                           |
| `value`  | any     | Giá trị phụ thuộc vào action                        |
| `ts`     | integer | Unix timestamp, giây                                 |

**Danh sách actions hợp lệ (smart-air v1):**

| `action`      | `value` type | Mô tả              |
| ------------- | ------------ | ------------------ |
| `set_power`   | boolean      | Bật/tắt thiết bị   |
| `set_mode`    | integer      | Đổi chế độ (1/2/3) |
| `ping`        | null         | Kiểm tra thiết bị còn sống không |

---

### 3.4 `device/{id}/response` — Kết quả lệnh

**Thành công:**
```json
{
  "cmd_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "ok",
  "ts": 1712345679
}
```

**Thất bại:**
```json
{
  "cmd_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "error",
  "reason": "sensor_busy",
  "ts": 1712345679
}
```

| `reason`        | Khi nào xảy ra                        |
| --------------- | ------------------------------------- |
| `sensor_busy`   | Đang đọc sensor, chưa execute được   |
| `invalid_action`| Action không tồn tại                 |
| `invalid_value` | Value không hợp lệ với action        |
| `duplicate_cmd` | cmd_id đã được xử lý rồi (idempotency) |

---

### 3.5 `device/{id}/shadow/report` — Device báo trạng thái

```json
{
  "reported": {
    "power": true,
    "mode": 1,
    "firmware": "1.0.3"
  },
  "ts": 1712345678
}
```

> ESP32 publish sau khi: boot xong, thực thi command thành công, hoặc có thay đổi state.

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

### 4.1 Device ONLINE — xử lý ngay

```
App                   API (Node.js)         EMQX              ESP32
 │                        │                   │                  │
 ├─POST /command──────────→│                   │                  │
 │                        ├─INSERT commands DB │                  │
 │                        ├─publish command───→│─────────────────→│
 │                        │                   │                  ├─check cmd_id (idempotency)
 │                        │                   │                  ├─execute action
 │                        │                   │←─publish response─┤
 │                        │←─subscribe response│                  │
 │                        ├─UPDATE commands status=done          │
 │←─FCM push notification─┤                   │                  │
```

**Timeout:** API chờ response tối đa **10 giây**. Sau 10 giây không có response → cập nhật status = `timeout`.

### 4.2 Device OFFLINE — queue lại

```
App                   API                  Redis               ESP32
 │                        │                   │                  │
 ├─POST /command──────────→│                   │                  │
 │                        ├─INSERT commands DB │                  │
 │                        ├─RPUSH pending_cmds:{id}─────────────→│ (offline)
 │←─202 "queued"──────────┤                   │                  │
 │                        │                   │    (boot + connect)
 │                        │                   │←─status online───┤
 │                        ├─LRANGE + flush────→│                  │
 │                        ├─publish command───→│─────────────────→│
 │                        │                   │                  ├─execute
 │←─FCM push notification─┤←─response─────────┤←─────────────────┤
```

---

## 5. Idempotency & Retry Rules

### 5.1 ESP32 phải làm gì khi nhận command

```
Nhận message trên device/{id}/command
    │
    ├─ Parse JSON, lấy cmd_id
    │
    ├─ Kiểm tra cmd_id trong processed_cmds[] (lưu trong RAM, tối đa 20 entries)
    │       │
    │       ├─ ĐÃ xử lý rồi → publish response cũ (status: duplicate_cmd) → bỏ qua
    │       │
    │       └─ CHƯA xử lý → thực thi action → lưu cmd_id vào processed_cmds[] → publish response
```

> Tại sao cần: MQTT QoS 1 đảm bảo "at least once" — broker có thể gửi lại cùng 1 message nếu không nhận được PUBACK. Không có idempotency, lệnh "bật đèn" có thể chạy 2 lần.

### 5.2 API retry policy

- API **không tự retry** command đã gửi qua MQTT.
- Nếu timeout: cập nhật status = `timeout`, app hiển thị lỗi, user tự gửi lại nếu muốn.
- Mỗi lần gửi lại = 1 `cmd_id` mới = 1 lần execute mới (không phải retry cũ).

### 5.3 ESP32 reconnect

- Sau khi reconnect WiFi/MQTT: publish `shadow/get` ngay lập tức.
- Server flush `pending_cmds:{deviceId}` từ Redis theo thứ tự FIFO.
- ESP32 xử lý từng command một, đợi response xong mới nhận command tiếp theo (không parallel).

---

## 6. Security Rules

- **ACL:** Device chỉ được pub/sub `device/{own_id}/*`. Device A không thể gửi command đến Device B.
- **TLS:** ESP32 kết nối port 8883 với embedded CA cert. Không dùng plain 1883.
- **Auth:** Mỗi device có `secret_key` riêng sinh ra lúc đăng ký, lưu trong NVS. Không hardcode.
- **Flutter:** Kết nối MQTT/WSS với JWT token (access token 15 phút). Hết hạn → refresh trước khi reconnect.

---

## 7. Ví dụ đầy đủ — Bật thiết bị khi device online

```
1. User bấm nút bật trong Flutter app

2. App gọi:
   POST /api/devices/550e8400.../command
   Body: { "payload": { "action": "set_power", "value": true } }

3. API tạo command record:
   cmd_id = "a1b2c3d4-..."
   status = "pending"

4. API kiểm tra Redis: device online → true

5. API publish MQTT:
   Topic: device/550e8400.../command
   Payload: {
     "cmd_id": "a1b2c3d4-...",
     "action": "set_power",
     "value": true,
     "ts": 1712345678
   }

6. ESP32 nhận, kiểm tra cmd_id chưa có trong processed_cmds[]
   → Thực thi: bật relay/LED
   → Lưu cmd_id vào processed_cmds[]
   → Publish response:
     Topic: device/550e8400.../response
     Payload: { "cmd_id": "a1b2c3d4-...", "status": "ok", "ts": 1712345679 }

7. API nhận response:
   → UPDATE commands SET status='done', executed_at=NOW()
   → Gửi FCM push notification đến app

8. App nhận push, cập nhật UI: nút hiển thị trạng thái "bật"
```

---

## 8. Changelog

| Ngày       | Thay đổi                        | Người thay đổi |
| ---------- | ------------------------------- | -------------- |
| 2026-04-13 | Khởi tạo file, version 1.0      | —              |
