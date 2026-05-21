# API Reference — smart-air

**Base URL:** `https://minhnhat05.xyz`
**Framework:** Fastify (Node.js) — port 3000 nội bộ, expose qua nginx → Cloudflare Tunnel
**Content-Type:** `application/json` cho tất cả request có body
**Auth:** JWT Bearer token — `Authorization: Bearer <accessToken>`
**CORS:** Chỉ cho phép `https://minhnhat05.xyz` (cấu hình qua env `CORS_ORIGINS`)

---

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Auth — Xác thực](#2-auth--xác-thực)
3. [Homes — Quản lý nhà](#3-homes--quản-lý-nhà)
4. [Rooms — Phòng](#4-rooms--phòng)
5. [Devices — Thiết bị](#5-devices--thiết-bị)
6. [Shadow — Trạng thái thiết bị](#6-shadow--trạng-thái-thiết-bị)
7. [Commands — Điều khiển](#7-commands--điều-khiển)
8. [Telemetry — Dữ liệu cảm biến](#8-telemetry--dữ-liệu-cảm-biến)
9. [Realtime — App SSE and MQTT WSS](#9-realtime--app-sse-and-mqtt-wss)
10. [Redis Keys Reference](#10-redis-keys-reference)
11. [MQTT Bridge — Server-side](#11-mqtt-bridge--server-side)
12. [Constants Reference](#12-constants-reference)
13. [Flows thực tế](#13-flows-thực-tế)
14. [Error Reference](#14-error-reference)

---

## 1. Tổng quan

### Endpoint Summary

| Method | Path                              | Auth  | Rate Limit | Mô tả                                  |
| ------ | --------------------------------- | :---: | :--------: | -------------------------------------- |
| GET    | `/api/health/live`                |       |            | Liveness check (process up)             |
| GET    | `/api/health/ready`               |       |            | Readiness check (DB + Redis + EMQX API + MQTT + realtime) |
| GET    | `/api/health`                     |       |            | Alias của readiness check               |
| POST   | `/api/auth/register`              |       |   10/min   | Đăng ký                                |
| POST   | `/api/auth/login`                 |       |   10/min   | Đăng nhập                              |
| POST   | `/api/auth/refresh`               |       |   10/min   | Refresh token                          |
| POST   | `/api/auth/logout`                |   🔒   |            | Đăng xuất                              |
| GET    | `/api/homes`                      |   🔒   |            | Danh sách nhà                          |
| POST   | `/api/homes`                      |   🔒   |            | Tạo nhà                                |
| PUT    | `/api/homes/:id`                  |   🔒   |            | Sửa nhà (owner/admin)                  |
| DELETE | `/api/homes/:id`                  |   🔒   |            | Xóa nhà (owner)                        |
| POST   | `/api/homes/:id/invite`           |   🔒   |            | Mời thành viên (owner/admin)           |
| GET    | `/api/homes/:homeId/rooms`        |   🔒   |            | Danh sách phòng                        |
| POST   | `/api/homes/:homeId/rooms`        |   🔒   |            | Tạo phòng (owner/admin)                |
| PUT    | `/api/rooms/:id`                  |   🔒   |            | Sửa phòng (owner/admin)                |
| DELETE | `/api/rooms/:id`                  |   🔒   |            | Xóa phòng (owner/admin)                |
| POST   | `/api/devices`                    |   🔒   |   20/min   | Đăng ký device                         |
| GET    | `/api/devices/announce/:mac`      |   🔒   |            | Kiểm tra device đã online              |
| GET    | `/api/devices`                    |   🔒   |            | Danh sách device                       |
| PUT    | `/api/devices/:id`                |   🔒   |            | Sửa device (member)                    |
| DELETE | `/api/devices/:id`                |   🔒   |            | Xóa device (owner/admin)               |
| GET    | `/api/devices/:id/shadow`         |   🔒   |            | Lấy shadow state                       |
| PUT    | `/api/devices/:id/shadow/desired` |   🔒   |            | Set desired state                      |
| POST   | `/api/devices/:id/command`        |   🔒   |   30/min   | Gửi command                            |
| POST   | `/api/devices/:id/relay/:channel` |   🔒   |   30/min   | Điều khiển relay trực tiếp             |
| GET    | `/api/devices/:id/commands`       |   🔒   |            | Lịch sử command                        |
| GET    | `/api/devices/:id/telemetry`      |   🔒   |            | Dữ liệu cảm biến                       |
| GET    | `/api/realtime`                   |   🔒   |            | App realtime stream (SSE)              |

### Authentication

Endpoint có 🔒 yêu cầu JWT access token:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

JWT payload: `{ sub: userId, email: userEmail }`
Access token hết hạn **15 phút** (env `JWT_EXPIRES_IN`).
Khi hết hạn → gọi `POST /api/auth/refresh`.

### Cấu trúc lỗi

```json
{ "error": "mô tả lỗi" }
```

| HTTP Code | Ý nghĩa                                              |
| --------- | ---------------------------------------------------- |
| 400       | Thiếu / sai định dạng request                        |
| 401       | Chưa đăng nhập hoặc token hết hạn                    |
| 403       | Không có quyền (sai role hoặc không phải thành viên) |
| 404       | Không tìm thấy tài nguyên                            |
| 409       | Xung đột — email/device đã tồn tại                   |
| 429       | Rate limit — quá nhiều request                       |
| 503       | Server degraded — một hoặc nhiều dependency down     |

### Role hệ thống

| Role     | Quyền                                                          |
| -------- | -------------------------------------------------------------- |
| `owner`  | Toàn quyền: xóa nhà, xóa device, mời thành viên, sửa nhà/phòng |
| `admin`  | Sửa nhà, tạo/sửa/xóa phòng, mời thành viên, xóa device         |
| `member` | Xem, gửi command, xem telemetry, đổi tên/chuyển phòng device   |

Role được enforce bằng `CHECK (role IN ('owner', 'admin', 'member'))` trong DB.

### Device ID

Device ID = MAC address ESP32, **lowercase**, format `aa:bb:cc:dd:ee:ff`.
Hàm `normalizeDeviceId()` validate regex `/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/` — trả `null` nếu invalid.

### Authorization Functions

| Function                                         | Kiểm tra                                 | Dùng cho                                         |
| ------------------------------------------------ | ---------------------------------------- | ------------------------------------------------ |
| `checkDeviceAccess(fastify, deviceId, userId)`   | User là member của home sở hữu device    | GET/PUT shadow, GET/POST command, GET telemetry  |
| `checkMembership(fastify, homeId, userId)`       | User là member của home (any role)       | GET rooms                                        |
| `requireRole(fastify, homeId, userId, ...roles)` | User có role cụ thể, throw 403 nếu không | DELETE home/device, PUT home, invite, CRUD rooms |

---

## 2. Auth — Xác thực

### `POST /api/auth/register`

Tạo tài khoản mới.

**Rate limit:** 10/phút/IP

**Request body:**

| Field       | Type   | Bắt buộc | Default |
| ----------- | ------ | :------: | ------- |
| `email`     | string |    ✓     | —       |
| `password`  | string |    ✓     | —       |
| `full_name` | string |          | `null`  |

```bash
curl -X POST https://minhnhat05.xyz/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"nhat@example.com","password":"matkhau123","full_name":"Minh Nhat"}'
```

**201 Created:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "nhat@example.com",
  "full_name": "Minh Nhat",
  "created_at": "2026-05-01T10:00:00.000Z"
}
```

| Error                | Code | Message                         |
| -------------------- | ---- | ------------------------------- |
| Thiếu email/password | 400  | `"email and password required"` |
| Email đã tồn tại     | 409  | `"Email already registered"`    |

**Internal:** bcrypt hash (`BCRYPT_ROUNDS = 12`), email lowercase trước khi lưu.

---

### `POST /api/auth/login`

Đăng nhập.

**Rate limit:** 10/phút/IP

**Request body:**

| Field      | Type   | Bắt buộc |
| ---------- | ------ | :------: |
| `email`    | string |    ✓     |
| `password` | string |    ✓     |

**200 OK:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "nhat@example.com",
    "full_name": "Minh Nhat"
  }
}
```

> `refreshToken` là UUID v4 (không phải JWT). Lưu vào secure storage trên mobile.

| Error                               | Code | Message                         |
| ----------------------------------- | ---- | ------------------------------- |
| Thiếu email/password                | 400  | `"email and password required"` |
| Sai password hoặc `is_active=false` | 401  | `"Invalid credentials"`         |

**Internal:**
- Access token: JWT, expiry 15m (`JWT_EXPIRES_IN`)
- Refresh token: UUID v4, expiry 30 ngày (`REFRESH_TOKEN_EXPIRES_DAYS`)
- INSERT `refresh_tokens` (token lưu dạng SHA-256 hash)
- SET HttpOnly cookie `refreshToken` (SameSite: Strict, path: `/api/auth/refresh`)
- Body cũng chứa `refreshToken` cho mobile client (không dùng cookie)

---

### `POST /api/auth/refresh`

Lấy access token mới. Flutter Dio interceptor gọi tự động khi 401.

**Rate limit:** 10/phút/IP

**Request body** (hoặc HttpOnly cookie):

| Field          | Type   |    Bắt buộc     |
| -------------- | ------ | :-------------: |
| `refreshToken` | string | ✓ (hoặc cookie) |

> Ưu tiên: `body.refreshToken` > `cookie.refreshToken`

**200 OK:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

| Error                 | Code | Message                              |
| --------------------- | ---- | ------------------------------------ |
| Không gửi token       | 401  | `"No refresh token"`                 |
| Token invalid/expired | 401  | `"Invalid or expired refresh token"` |

**Internal:**
1. Tìm token trong `refresh_tokens` (JOIN users), check `expires_at > NOW()`
2. Trong cùng transaction: ghi `refresh_token_reuse_markers`, DELETE token cũ, INSERT token mới
3. Nếu duplicate refresh request tới gần như đồng thời, request thua sẽ nhận `401` nhưng không revoke token mới vừa rotate
4. Nếu token cũ bị dùng lại sau grace window, server tìm marker và revoke toàn bộ refresh sessions của user
5. Issue access token mới

---

### `POST /api/auth/logout` 🔒

Đăng xuất toàn bộ session.

**200 OK:**
```json
{ "success": true }
```

**Internal:**
1. DELETE tất cả `refresh_tokens` theo `user_id` (logout everywhere)
2. Clear cookie `refreshToken`

---

## 3. Homes — Quản lý nhà

### `GET /api/homes` 🔒

Danh sách nhà user là thành viên.

**200 OK:**
```json
[
  {
    "id": "uuid",
    "owner_id": "uuid",
    "name": "Nhà Bình Thạnh",
    "address": "Bình Thạnh, TP.HCM",
    "timezone": "Asia/Ho_Chi_Minh",
    "created_at": "2026-04-01T00:00:00.000Z"
  }
]
```

Sắp xếp `created_at ASC`. Trả `[]` nếu chưa thuộc nhà nào.

---

### `POST /api/homes` 🔒

Tạo nhà mới. User tự động thành `owner`.

**Request body:**

| Field      | Type   | Bắt buộc | Default              |
| ---------- | ------ | :------: | -------------------- |
| `name`     | string |    ✓     | —                    |
| `address`  | string |          | `null`               |
| `timezone` | string |          | `"Asia/Ho_Chi_Minh"` |

**201 Created:** Home object.

| Error      | Code | Message           |
| ---------- | ---- | ----------------- |
| Thiếu name | 400  | `"name required"` |

**Internal:** Transaction — INSERT `homes` + INSERT `home_members` (role='owner'). Rollback nếu một trong hai fail.

---

### `PUT /api/homes/:id` 🔒

Sửa nhà. **owner/admin**.

**Request body** (optional, COALESCE — field không gửi giữ nguyên):

| Field      | Type   |
| ---------- | ------ |
| `name`     | string |
| `address`  | string |
| `timezone` | string |

**200 OK:** Updated home object.

| Error                  | Code | Message       |
| ---------------------- | ---- | ------------- |
| Không phải owner/admin | 403  | `"Forbidden"` |
| Home không tồn tại     | 404  | `"Not found"` |

---

### `DELETE /api/homes/:id` 🔒

Xóa nhà. **Chỉ owner**.

**204 No Content.**

| Error            | Code | Message       |
| ---------------- | ---- | ------------- |
| Không phải owner | 403  | `"Forbidden"` |

**Internal:**
1. Trong cùng DB transaction: owner check + lock `homes` row bằng `FOR UPDATE`
2. Capture device IDs rồi DELETE `homes`; DB cascade xóa devices/rooms/home_members
3. Trigger `AFTER DELETE ON devices` tạo `external_cleanup_jobs(kind='emqx_device_user')`
4. Sau commit: best-effort cleanup Redis + EMQX cho các device IDs đã capture

---

### `POST /api/homes/:id/invite` 🔒

Mời thành viên bằng email. **owner/admin**.

**Request body:**

| Field   | Type   | Bắt buộc | Default    |
| ------- | ------ | :------: | ---------- |
| `email` | string |    ✓     | —          |
| `role`  | string |          | `"member"` |

**200 OK:** `{ "success": true }`

| Error                  | Code | Message              |
| ---------------------- | ---- | -------------------- |
| Email thiếu/sai format | 400  | `"valid email required"` |
| Không phải owner/admin | 403  | `"Forbidden"`        |
| Email chưa đăng ký     | 200  | `{ "success": true }` để tránh lộ email đã đăng ký |
| Đã là thành viên       | 409  | `"Already a member"` |

---

## 4. Rooms — Phòng

### `GET /api/homes/:homeId/rooms` 🔒

Danh sách phòng. **Mọi thành viên** xem được.

**200 OK:**
```json
[
  { "id": "uuid", "home_id": "uuid", "name": "Phòng ngủ", "icon": "bed" }
]
```

Sắp xếp `name ASC`. Authorization: `checkMembership()`.

| Error                 | Code | Message       |
| --------------------- | ---- | ------------- |
| Không phải thành viên | 403  | `"Forbidden"` |

---

### `POST /api/homes/:homeId/rooms` 🔒

Tạo phòng. **owner/admin**.

| Field  | Type   | Bắt buộc |
| ------ | ------ | :------: |
| `name` | string |    ✓     |
| `icon` | string |          |

**201 Created:** Room object.

| Error                  | Code | Message           |
| ---------------------- | ---- | ----------------- |
| Thiếu name             | 400  | `"name required"` |
| Không phải owner/admin | 403  | `"Forbidden"`     |

---

### `PUT /api/rooms/:id` 🔒

Sửa phòng. **owner/admin**.

| Field  | Type   |
| ------ | ------ |
| `name` | string |
| `icon` | string |

**200 OK:** Updated room object.

| Error                  | Code | Message       |
| ---------------------- | ---- | ------------- |
| Không phải owner/admin | 403  | `"Forbidden"` |
| Room không tồn tại     | 404  | `"Not found"` |

**Internal:** Truy vấn `home_id` từ room, sau đó `requireRole()`.

---

### `DELETE /api/rooms/:id` 🔒

Xóa phòng. **owner/admin**. Devices trong phòng sẽ SET `room_id = NULL` (không bị xóa).

**204 No Content.**

| Error                  | Code | Message       |
| ---------------------- | ---- | ------------- |
| Không phải owner/admin | 403  | `"Forbidden"` |
| Room không tồn tại     | 404  | `"Not found"` |

---

## 5. Devices — Thiết bị

### `POST /api/devices` 🔒

Đăng ký ESP32 sau BLE provisioning.

> Đây là bước backend cấp credential MQTT riêng cho thiết bị.
> Thiết bị không tự xuất hiện trong EMQX chỉ vì đã bật nguồn, đã pair BLE, hay đã vào Wi-Fi.

**Rate limit:** 20/phút/IP

**Request body:**

| Field       | Type          | Bắt buộc | Validation                     |
| ----------- | ------------- | :------: | ------------------------------ |
| `device_id` | string        |    ✓     | MAC format `aa:bb:cc:dd:ee:ff` |
| `name`      | string        |    ✓     | —                              |
| `home_id`   | string (UUID) |    ✓     | UUID regex                     |
| `room_id`   | string (UUID) |          | —                              |

**201 Created:**
```json
{
  "id": "dc:b4:d9:13:ed:8c",
  "name": "Cảm biến phòng ngủ",
  "home_id": "uuid",
  "room_id": null,
  "type_id": "uuid",
  "owner_id": "uuid",
  "secret_key": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "online": false,
  "last_seen": null,
  "firmware_ver": null,
  "created_at": "2026-05-01T10:00:00.000Z"
}
```

> `secret_key` là MQTT password. Chỉ trả về **1 lần** khi tạo device.

| Error                      | Code | Message                               |
| -------------------------- | ---- | ------------------------------------- |
| Thiếu fields               | 400  | `"device_id, name, home_id required"` |
| room_id sai format         | 400  | `"room_id must be a valid UUID"`      |
| room không thuộc home      | 400  | `"room_id does not belong to home"`   |
| Không phải owner/admin     | 403  | `"Forbidden"`                         |
| Device đã tồn tại          | 409  | `"Device already registered"`         |
| EMQX đã có user orphan     | 409  | `"Device provisioning conflict"`      |
| Quá quota device của home  | 429  | `"device limit reached for this home"` |
| EMQX Admin API fail/timeout | 502 | `"Device provisioning failed"`        |

**Internal:**
1. `normalizeDeviceId()` — validate MAC + lowercase
2. `requireRole('owner', 'admin')` trên home
3. Trong transaction: lock quota, check duplicate device, check room thuộc home, check quota
4. Tạo `secret_key = uuidv4()`
5. EMQX: tạo MQTT user + ACL với timeout `EMQX_API_TIMEOUT_MS` (default 5000 ms); nếu user đã tồn tại nhưng DB chưa có device thì trả 409, không overwrite password
6. INSERT `devices`; nếu DB fail sau khi tạo EMQX user thì cleanup compensation
7. Trả `secret_key` về app đúng 1 lần để app hoặc provisioning flow chuyển credential đó xuống firmware trước khi thiết bị login MQTT

---

### `GET /api/devices/announce/:mac` 🔒

Kiểm tra ESP32 đã announce online chưa (polling sau BLE provisioning).

**200 OK:** `{ "announced": true }` hoặc `{ "announced": false }`

| Error       | Code | Message         |
| ----------- | ---- | --------------- |
| MAC invalid | 400  | `"Invalid mac"` |

**Internal:** Redis key `announce:{deviceId}`, TTL 300s (`REDIS_TTL_ANNOUNCE`).

> Polling mỗi 2-3s sau provisioning cho đến khi `announced: true` hoặc timeout 30s.

---

### `GET /api/devices` 🔒

Danh sách device thuộc các nhà của user.

**200 OK:**
```json
[
  {
    "id": "dc:b4:d9:13:ed:8c",
    "name": "Cảm biến phòng ngủ",
    "home_id": "uuid",
    "room_id": null,
    "online": true,
    "last_seen": "2026-05-01T10:05:00.000Z",
    "firmware_ver": "1.0.0",
    "created_at": "2026-04-01T00:00:00.000Z"
  }
]
```

Sắp xếp `created_at ASC`. **Không** bao gồm `secret_key`, `type_id`, `owner_id`.

---

### `PUT /api/devices/:id` 🔒

Đổi tên/chuyển phòng. **Mọi thành viên** (via `checkDeviceAccess`).

| Field     | Type          |
| --------- | ------------- |
| `name`    | string        |
| `room_id` | string (UUID) |

**200 OK:**
```json
{
  "id": "dc:b4:d9:13:ed:8c",
  "name": "Tên mới",
  "home_id": "uuid",
  "room_id": "uuid",
  "online": true,
  "last_seen": "2026-05-01T10:05:00.000Z",
  "firmware_ver": "1.0.0"
}
```

| Error                 | Code | Message               |
| --------------------- | ---- | --------------------- |
| Invalid MAC           | 400  | `"Invalid device ID"` |
| Không phải thành viên | 403  | `"Forbidden"`         |
| Device không tồn tại  | 404  | `"Not found"`         |

---

### `DELETE /api/devices/:id` 🔒

Xóa device. **owner/admin** (via `requireRole`).

**204 No Content.**

| Error                  | Code | Message               |
| ---------------------- | ---- | --------------------- |
| Invalid MAC            | 400  | `"Invalid device ID"` |
| Không phải owner/admin | 403  | `"Forbidden"`         |
| Device không tồn tại   | 404  | `"Not found"`         |

**Internal:**
1. Verify role `owner/admin` trên home chứa device
2. Trong cùng DB transaction: lock device row, verify role, rồi DELETE `devices`
3. Trigger `AFTER DELETE ON devices` tạo `external_cleanup_jobs(kind='emqx_device_user')`
4. Sau commit: best-effort DEL Redis `shadow:`, `pending_cmds:`, `announce:`, `ota_progress:`
5. EMQX: xóa user + ACL; nếu fail thì giữ DB cleanup job để retry

---

## 6. Shadow — Trạng thái thiết bị

Shadow = snapshot state gồm:
- **`reported`**: ESP32 tự báo (nhiệt độ, độ ẩm, firmware, timestamp)
- **`desired`**: App set (fan_speed, led, timer...)

Cache: Redis `shadow:{deviceId}` TTL 1h (`REDIS_TTL_SHADOW`), fallback DB `device_shadows`.
Malformed Redis JSON is deleted. Cache writes are versioned by `updatedAt`, and a failed write clears the key so stale Redis state cannot outrun Postgres.
For `device/{id}/shadow/report`, top-level `reported.ts` is the ordering key: older reports are ignored so out-of-order MQTT delivery cannot overwrite newer state.

### `GET /api/devices/:id/shadow` 🔒

Authorization: `checkDeviceAccess()`

**200 OK:**
```json
{
  "reported": {
    "temperature": 28.5,
    "humidity": 65.2,
    "firmware": "1.0.0",
    "ts": 1777631000
  },
  "desired": {
    "fan_speed": 2,
    "led": true
  },
  "updatedAt": "2026-05-01T10:05:00.000Z"
}
```

> Device chưa có shadow: `{ "reported": {}, "desired": {}, "updatedAt": null }`

| Error                 | Code | Message               |
| --------------------- | ---- | --------------------- |
| Invalid MAC           | 400  | `"Invalid device ID"` |
| Không phải thành viên | 403  | `"Forbidden"`         |

---

### `PUT /api/devices/:id/shadow/desired` 🔒

Authorization: `checkDeviceAccess()`

**Request body:** JSON object bất kỳ, ngoại trừ các reserved keys `mode`, `relay_1`, `relay_2`, `relay_3`. Các key này phải đi qua typed endpoints riêng cho device mode và relay control.

```json
{ "fan_speed": 3, "led": false }
```

**200 OK:** `{ "success": true }`

| Error                  | Code | Message                      |
| ---------------------- | ---- | ---------------------------- |
| Body không phải object | 400  | `"body must be a plain JSON object"` |
| Reserved keys          | 400  | `"Reserved keys detected: ... Use typed endpoints for device mode and relay control."` |
| Body vượt size limit   | 400  | `"desired shadow payload exceeds size limit"` |
| Invalid MAC            | 400  | `"Invalid device ID"`        |
| Không phải thành viên  | 403  | `"Forbidden"`                |

**Internal:**
1. Validate plain object + size limit, rồi `setDesired()` UPSERT DB + write-through Redis cache
2. Nếu device online → MQTT publish `device/{id}/shadow/get_response`:
   ```json
   { "desired": { "fan_speed": 3, "led": false }, "delta": { "fan_speed": 3, "led": false }, "ts": 1777631761 }
   ```
3. Nếu offline → chỉ lưu DB, push khi device online lại hoặc khi device publish `shadow/get`

---

## 7. Commands — Điều khiển

### `POST /api/devices/:id/command` 🔒

**Rate limit:** 30/phút/IP
Authorization: `checkDeviceAccess()`

**Request body:**

| Field     | Type   | Bắt buộc |
| --------- | ------ | :------: |
| `payload` | object |    ✓     |

```bash
curl -X POST https://minhnhat05.xyz/api/devices/dc:b4:d9:13:ed:8c/command \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"payload":{"type":"set_time","ts":1777631761}}'
```

**201 Created:**
```json
{ "command_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479" }
```

| Error                 | Code | Message               |
| --------------------- | ---- | --------------------- |
| Invalid MAC           | 400  | `"Invalid device ID"` |
| Thiếu/sai payload     | 400  | `"payload required"`  |
| Không phải thành viên | 403  | `"Forbidden"`         |

**Internal (device online):**
1. INSERT `commands` status=`pending`
2. `flushPending()` lấy pending commands từ PostgreSQL theo FIFO
3. UPDATE status=`sent` + COMMIT dispatch record
4. MQTT publish `device/{id}/command`: `{ command_id, ...payload }`
5. Nếu publish call fail đồng bộ, server revert row về `pending`

**Internal (device offline):**
1. INSERT `commands` status=`pending`
2. Khi device online → `flushPending()` lấy pending commands từ DB và gửi từng command

**Command lifecycle:** `pending` → `sent` → `done` | `error` | `timeout`

> Status cuối do firmware quyết định hoặc timeout job. CHECK constraint: `('pending','sent','done','error','timeout')`.

**Các lệnh thực tế:**

| Lệnh              | Payload                                                 |
| ----------------- | ------------------------------------------------------- |
| Relay             | `{ "type": "relay_set", "relay": 1, "state": true }`    |
| Device mode       | `{ "type": "device_mode", "mode": "on" }`               |
| Đồng bộ thời gian | `{ "type": "set_time", "ts": 1777631761 }`              |
| Calibrate CO      | `{ "type": "calibrate_co" }`                            |
| Calibrate NO2     | `{ "type": "calibrate_no2" }`                           |

> Calibration là maintenance command nhưng vẫn dùng quyền member như các command generic khác.

`set_config` và `ota_update` không được nhận qua generic command endpoint. OTA hiện đi qua topic riêng `device/{id}/ota/update`.

> ESP32 nhận → thực thi → publish `device/{id}/response`: `{ command_id, status: "done" }`
> Server `handleResponse()` → UPDATE `commands.status`, `executed_at = NOW()`.

---

### `POST /api/devices/:id/relay/:channel` 🔒

**Rate limit:** 30/phút/IP
Authorization: `checkDeviceAccess()`

Typed endpoint để điều khiển trực tiếp relay, tương đương payload command:
`{ "type": "relay_set", "relay": <channel>, "state": <boolean> }`

**Path params:**

| Param     | Type    | Ràng buộc |
| --------- | ------- | --------- |
| `id`      | string  | Device ID hợp lệ |
| `channel` | integer | `1..3` |

**Request body:**

```json
{ "state": true }
```

**201 Created:**
```json
{ "command_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479" }
```

| Error                          | Code | Message               |
| ------------------------------ | ---- | --------------------- |
| Invalid MAC                    | 400  | `"Invalid device ID"` |
| `channel` ngoài `1..3` / body thiếu `state` | 400  | Fastify schema validation |
| Không phải thành viên          | 403  | `"Forbidden"`         |

**Internal:** Server chuẩn hóa thành command payload `relay_set`, lưu vào `commands`, rồi dispatch qua cùng luồng `sendCommand()` như endpoint generic.

---

### `GET /api/devices/:id/commands` 🔒

Lịch sử command, mới nhất trước. Authorization: `checkDeviceAccess()`

**Query params:**

| Param    | Default | Max                        |
| -------- | ------- | -------------------------- |
| `limit`  | 50      | 200 (`COMMANDS_MAX_LIMIT`) |
| `offset` | 0       | —                          |

**200 OK:**
```json
[
  {
    "id": "uuid",
    "payload": { "type": "set_time", "ts": 1777631761 },
    "status": "done",
    "created_at": "2026-05-01T10:00:00.000Z",
    "executed_at": "2026-05-01T10:00:01.243Z"
  }
]
```

| Error                 | Code | Message               |
| --------------------- | ---- | --------------------- |
| Invalid MAC           | 400  | `"Invalid device ID"` |
| Không phải thành viên | 403  | `"Forbidden"`         |

---

## 8. Telemetry — Dữ liệu cảm biến

ESP32 publish mỗi 5s lên `device/{id}/telemetry`. Server `handleTelemetry()` INSERT vào TimescaleDB hypertable. QoS-1 redelivery được dedupe theo `(device_id, ts, mqtt_message_id)` khi packet metadata có sẵn. Retention: 1 year.

### `GET /api/devices/:id/telemetry` 🔒

Authorization: `checkDeviceAccess()`

**Query params:**

| Param   | Default   | Max  | Mô tả                                                 |
| ------- | --------- | ---- | ----------------------------------------------------- |
| `from`  | 24h trước | —    | ISO 8601                                              |
| `to`    | Hiện tại  | —    | ISO 8601                                              |
| `limit` | 1000      | 5000 | Chỉ áp dụng raw mode                                  |
| `agg`   | _(none)_  | —    | Whitelist: `1m`, `5m`, `15m`, `30m`, `1h`, `6h`, `1d` |

> Khi có `agg`: `time_bucket()` + AVG, vẫn áp dụng `limit` cho số bucket trả về.
> Khi không có `agg`: raw data, áp dụng `limit`.
> Ràng buộc thời gian: `from` phải `<= to`, và `to - from` không được vượt quá `90 ngày`.

**200 OK (raw):**
```json
[
  { "ts": "2026-05-01T10:05:00.000Z", "temperature": 28.5, "humidity": 65.2 },
  { "ts": "2026-05-01T10:04:55.000Z", "temperature": 28.4, "humidity": 65.0 }
]
```

**200 OK (agg=1h):**
```json
[
  { "ts": "2026-05-01T10:00:00.000Z", "temperature": 28.4, "humidity": 65.1 },
  { "ts": "2026-05-01T09:00:00.000Z", "temperature": 27.9, "humidity": 64.5 }
]
```

Sắp xếp `ts DESC`.

| Error                 | Code | Message                                                      |
| --------------------- | ---- | ------------------------------------------------------------ |
| `from > to`           | 400  | `"from must be <= to"`                                       |
| Range vượt `90 ngày`  | 400  | `"range must be <= 90 days"`                                 |
| `from` / `to` sai định dạng | 400  | `"invalid from/to date (ISO8601 expected)"`                  |
| Invalid MAC           | 400  | `"Invalid device ID"`                                        |
| `agg` không hợp lệ    | 400  | `"Invalid agg value. Allowed: 1m, 5m, 15m, 30m, 1h, 6h, 1d"` |
| Không phải thành viên | 403  | `"Forbidden"`                                                |

**Flutter `fl_chart` guide:**

| Chart mode  | `agg`    | `limit`  | `from`      |
| ----------- | -------- | -------- | ----------- |
| 1h realtime | _(none)_ | 720      | `now - 1h`  |
| 24h         | `1h`     | _(omit)_ | `now - 24h` |
| 7 ngày      | `6h`     | _(omit)_ | `now - 7d`  |
| 30 ngày     | `1d`     | _(omit)_ | `now - 30d` |

---

## 9. Realtime — App SSE and MQTT WSS

### `GET /api/realtime` 🔒

App-facing realtime stream. This endpoint uses the same JWT session and device ownership checks as the REST API.
It is the default realtime transport for Flutter UI state.

```text
Authorization: Bearer <accessToken>
Accept: text/event-stream
Last-Event-ID: <optional event id>
```

Nginx disables buffering for this exact path. Server sends heartbeat comments to keep the connection open.

**SSE frame:**

```text
id: 12345
event: telemetry.point
data: {"id":"12345","type":"telemetry.point","device_id":"aa:bb:cc:dd:ee:ff","occurred_at":"2026-05-15T10:00:00.000Z","payload":{}}
```

**Envelope fields:**

| Field         | Type   | Mô tả                                          |
| ------------- | ------ | ---------------------------------------------- |
| `id`          | string | Monotonic realtime event id for reconnect replay |
| `type`        | string | Event type, also used as the SSE `event` field |
| `device_id`   | string | Device id this event belongs to                |
| `occurred_at` | string | ISO timestamp for the underlying state change  |
| `payload`     | object | Type-specific app payload                      |

**Event types:**

| Type              | Produced after                                  | Payload shape |
| ----------------- | ----------------------------------------------- | ------------- |
| `telemetry.point` | Telemetry DB insert succeeds                    | `{ ts, temperature, humidity, co_ppm, no2_ppm, mode }` |
| `device.status`  | Device row online/last_seen update succeeds     | `{ online, firmware }` |
| `shadow.reported`| Reported shadow update succeeds                 | `{ reported, patch }` |
| `command.updated`| Command row changes status                      | `{ command_id, status, payload?, error_message? }` |
| `ota.progress`   | OTA progress Redis write succeeds               | OTA progress payload |

REST remains canonical for initial snapshots, history, reconnect backfill beyond the SSE replay window, and fallback.
Realtime events are retained for short reconnect replay (`REALTIME_EVENT_RETENTION_HOURS`, default 24h).
When an event source provides a stable idempotency key, retried inserts reuse the existing `realtime_events` row and do not emit duplicate SSE replay/history entries.

### MQTT WebSocket — broker clients

```text
Public URL:   wss://minhnhat05.xyz/mqtt
Internal hop: nginx /mqtt -> emqx:8083
Protocol:     MQTT v3.1.1 over WebSocket
```

> EMQX không publish port `8083` ra host.
> WebSocket path này chỉ đi qua `nginx` và Cloudflare Tunnel, không phải `ws://127.0.0.1:8083`.

> **Lưu ý:** Flutter app production flow dùng `/api/realtime`, không subscribe trực tiếp `/mqtt`.
> Nếu dùng WebSocket MQTT trực tiếp, EMQX đang xác thực bằng MQTT username/password theo built-in database; JWT của REST API không được dùng cho MQTT/WSS.

**Topics subscribe:**

| Topic                      | Payload                                                           | Dùng để         |
| -------------------------- | ----------------------------------------------------------------- | --------------- |
| `device/{id}/status`       | `{"online":true,"firmware":"1.0.0"}`                              | Online/offline  |
| `device/{id}/telemetry`    | `{"device_id":"...","ts":123,"temperature":28.5,"humidity":65.2}` | Realtime sensor |
| `device/{id}/ota/progress` | `{"progress":50,"status":"downloading"}`                          | OTA progress    |

---

## 10. Redis Keys Reference

| Key                                | Type        | TTL       | Set bởi                          |
| ---------------------------------- | ----------- | --------- | -------------------------------- |
| `announce:{deviceId}`              | string      | 300s      | `handleStatus()`                 |
| `shadow:{deviceId}`                | JSON string | 3600s     | `getShadow()` (cache)            |
| `pending_cmds:{deviceId}`          | list        | legacy    | Dọn khi delete device            |
| `ota_progress:{deviceId}`          | JSON string | 600s      | `handleOtaProgress()`            |

---

## 11. MQTT Bridge — Server-side

Client ID `sa-api-bridge`, kết nối `mqtt://emqx:1883` (internal Docker network).
EMQX Admin API provisioning/cleanup dùng `EMQX_API_URL` và timeout `EMQX_API_TIMEOUT_MS` (default 5000 ms).

**Subscribe:**

| Topic                    | Handler               | Xử lý                                                                                         |
| ------------------------ | --------------------- | --------------------------------------------------------------------------------------------- |
| `device/+/status`        | `handleStatus()`      | Validate `{online:boolean}`; UPDATE `devices.online` + `last_seen`; emit `device.status`; SET `announce:`; `flushPending()`; push desired shadow |
| `device/+/telemetry`     | `handleTelemetry()`   | Validate device/topic, mode, sensor fields, ts; INSERT TimescaleDB with QoS-1 dedupe; emit `telemetry.point` |
| `device/+/response`      | `handleResponse()`    | UPDATE `commands.status` + `executed_at`; emit `command.updated`. Status whitelist: `done`/`error` |
| `device/+/shadow/report` | `handleShadowReport()`| Drop unknown devices, validate known fields, UPSERT `device_shadows` only when `payload.ts` is not older than current `reported.ts`; emit `shadow.reported` only for applied updates |
| `device/+/shadow/get`    | `handleShadowGet()`   | Load shadow and publish `shadow/get_response`                                                  |
| `device/+/ota/progress`  | `handleOtaProgress()` | SET Redis TTL 600s; emit `ota.progress`                                                       |

**Publish:**

| Topic                             | Khi nào                               | Payload                      |
| --------------------------------- | ------------------------------------- | ---------------------------- |
| `device/{id}/command`             | `sendCommand()` / `flushPending()`    | `{ command_id, ...payload }` |
| `device/{id}/shadow/get_response` | Device online / `PUT /shadow/desired` / `shadow/get` | `{ desired, delta, ts }` |

---

## 12. Constants Reference

Tất cả centralized tại `src/constants.js`:

| Constant                  | Giá trị                      | Dùng cho                            |
| ------------------------- | ---------------------------- | ----------------------------------- |
| `REDIS_TTL_ANNOUNCE`      | 300                          | TTL `announce:` key                 |
| `REDIS_TTL_OTA`           | 600                          | TTL `ota_progress:` key             |
| `REDIS_TTL_SHADOW`        | 3600                         | TTL `shadow:` cache                 |
| `BCRYPT_ROUNDS`           | 12                           | Password hash strength              |
| `REFRESH_COOKIE_PATH`     | `/api/auth/refresh`          | Cookie path                         |
| `SECONDS_PER_DAY`         | 86400                        | Refresh token expiry calc           |
| `ALLOWED_ORIGINS`         | `['https://minhnhat05.xyz']` | CORS (env override: `CORS_ORIGINS`) |
| `RATE_LIMIT_COMMAND`      | 30/min                       | POST /command                       |
| `RATE_LIMIT_DEVICE`       | 20/min                       | POST /devices                       |
| `AGG_ALLOWED`             | `1m,5m,15m,30m,1h,6h,1d`     | Telemetry agg whitelist             |
| `COMMANDS_MAX_LIMIT`      | 200                          | Max limit query commands            |
| `TELEMETRY_DEFAULT_LIMIT` | 1000                         | Default limit telemetry             |
| `TELEMETRY_MAX_LIMIT`     | 5000                         | Max limit telemetry                 |
| `MS_PER_DAY`              | 86400000                     | Default `from` (24h trước)          |

---

## 13. Flows thực tế

### Flow 1 — BLE Provisioning → Device online

```
 1. ESP32 boot → BLE advertising "SMART_AIR_13ED8C"
 2. Flutter scan BLE → connect GATT
 3. Flutter write SSID → characteristic 0xFF01
 4. Flutter write Password → characteristic 0xFF02
 5. ESP32 join Wi-Fi
 6. ESP32 notify Flutter qua 0xFF03: {"ip":"192.168.1.26","device_id":"aa:bb:cc:dd:ee:ff","status":"ok"}
 7. Flutter POST /api/devices { device_id, name, home_id, room_id? }
 8. Server tạo EMQX user + ACL → trả về secret_key đúng 1 lần
9. App chuyển `device_id` + `secret_key` xuống firmware qua local endpoint `POST http://<device-ip>/api/config`
10. ESP32 validate `device_id` phải trùng Wi-Fi STA MAC, lưu credential vào NVS, reboot, rồi kết nối MQTT broker (`wss://minhnhat05.xyz/mqtt` mặc định)
11. ESP32 publish device/{device_id}/status = {"online":true,"firmware":"1.0.0"}
12. Server handleStatus() → UPDATE devices → SET announce:{device_id} TTL 300s
13. Flutter polling GET /api/devices/announce/{device_id} → announced: true
14. Flutter navigate → device detail screen
```

> Firmware local endpoint `POST /api/config` nhận JSON:
> `{ "device_id": "aa:bb:cc:dd:ee:ff", "secret_key": "...", "broker_uri": "wss://minhnhat05.xyz/mqtt" }`.
> `broker_uri` optional; nếu bỏ qua firmware xóa override cũ và dùng Kconfig default.
> Endpoint này là local device provisioning, không phải public server REST endpoint.

### Flow 2 — Realtime Dashboard

```
1. Flutter mở device detail
2. GET /api/devices/:id/shadow → hiển thị reported/desired state hiện tại
3. GET /api/devices/:id/telemetry?from=now-30m&limit=... → initial live snapshot
4. GET /api/realtime → subscribe SSE bằng JWT
5. ESP32 publish telemetry/status/shadow/response/OTA qua MQTT
6. Server persist state → insert `realtime_events` → SSE emits app event
7. Flutter Riverpod live store append/merge event without remounting the screen
8. Nếu reconnect vượt replay window, Flutter refetch snapshot/history qua REST
```

### Flow 3 — Command set_time

```
1. Flutter POST /api/devices/:id/command { payload: { type: "set_time", ts: ... } }
2. Server INSERT commands status='pending'
3. Device online → MQTT publish device/{id}/command: { command_id, type, ts }
4. Server UPDATE status='sent'
5. ESP32 nhận → cập nhật DS3231 RTC
6. ESP32 publish device/{id}/response: { command_id, status: "done" }
7. Server handleResponse() → UPDATE status='done', executed_at=NOW(), emit `command.updated`
8. Flutter SSE updates recent command state; REST command history remains available for history/backfill
```

### Flow 4 — OTA thủ công

```
1. idf.py build
2. scp build/smart-air.bin → Pi:~/Working_Space/smart-air/server/ota-files/
3. sha256sum smart-air.bin
4. EMQX Dashboard → publish device/{id}/ota/update:
   {"url":"https://192.168.1.16/ota/smart-air.bin","sha256":"<hash>"}
5. ESP32 download → verify SHA256 → reboot
6. Server handleOtaProgress() → Redis ota_progress:{id}
7. ESP32 boot → ota_validate_and_commit() → committed
```

### Admin surfaces hiện có

| Surface             | URL / Port                         | Ghi chú |
| ------------------- | ---------------------------------- | ------- |
| EMQX Dashboard      | `http://127.0.0.1:18083`           | localhost only |
| pgAdmin             | `http://127.0.0.1:5050`            | localhost only |
| Portainer           | `http://127.0.0.1:9000`            | localhost only |
| Grafana public path | `https://minhnhat05.xyz/grafana/`  | qua nginx + cloudflared |
| API public path     | `https://minhnhat05.xyz/api/...`   | qua nginx + cloudflared |

> `api`, `nginx`, `grafana`, và `redis` không bind port trực tiếp ra host trong `docker-compose.yml`.

---

## 14. Error Reference

### Auth Errors

| Situation                  | Code | Body                          |
| -------------------------- | ---- | ----------------------------- |
| Thiếu Authorization header | 401  | `{ "error": "Unauthorized" }` |
| Token hết hạn / invalid    | 401  | `{ "error": "Unauthorized" }` |

### Permission Errors

| Situation                                    | Code | Body                                                                           |
| -------------------------------------------- | ---- | ------------------------------------------------------------------------------ |
| `checkDeviceAccess` / `checkMembership` fail | 403  | `{ "error": "Forbidden" }`                                                     |
| `requireRole` fail                           | 403  | Fastify: `{ "statusCode": 403, "error": "Forbidden", "message": "Forbidden" }` |

### Validation Errors

| Situation              | Code | Message                                                      |
| ---------------------- | ---- | ------------------------------------------------------------ |
| Thiếu email/password   | 400  | `"email and password required"`                              |
| Thiếu name (home/room) | 400  | `"name required"`                                            |
| Email invite invalid   | 400  | `"valid email required"`                                     |
| Thiếu device fields    | 400  | `"device_id, name, home_id required"`                        |
| room_id sai UUID       | 400  | `"room_id must be a valid UUID"`                             |
| room không thuộc home  | 400  | `"room_id does not belong to home"`                          |
| Device ID sai MAC      | 400  | `"Invalid device ID"` hoặc `"Invalid mac"`                   |
| Thiếu command payload  | 400  | `"payload required"`                                         |
| Shadow body sai format | 400  | `"body must be a plain JSON object"`                         |
| Telemetry agg sai      | 400  | `"Invalid agg value. Allowed: 1m, 5m, 15m, 30m, 1h, 6h, 1d"` |

### Conflict Errors

| Situation         | Code | Message                       |
| ----------------- | ---- | ----------------------------- |
| Email đã đăng ký  | 409  | `"Email already registered"`  |
| Device đã tồn tại | 409  | `"Device already registered"` |
| Đã là thành viên  | 409  | `"Already a member"`          |

### Infrastructure Errors

| Situation           | Code | Body                                                                         |
| ------------------- | ---- | ---------------------------------------------------------------------------- |
| DB/Redis/MQTT down  | 503  | `{ "status": "degraded", "ts": ..., "checks": { "postgres": "fail", ... } }` |
| Rate limit exceeded | 429  | `{ "statusCode": 429, "error": "Too Many Requests", ... }`                   |
