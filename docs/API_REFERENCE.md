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
9. [MQTT WebSocket — Realtime](#9-mqtt-websocket--realtime)
10. [Redis Keys Reference](#10-redis-keys-reference)
11. [MQTT Bridge — Server-side](#11-mqtt-bridge--server-side)
12. [Constants Reference](#12-constants-reference)
13. [Flows thực tế](#13-flows-thực-tế)
14. [Error Reference](#14-error-reference)

---

## 1. Tổng quan

### Endpoint Summary

| Method | Path | Auth | Rate Limit | Mô tả |
|--------|------|:----:|:----------:|-------|
| GET | `/api/health` | | | Health check (deep: DB + Redis + MQTT) |
| POST | `/api/auth/register` | | 10/min | Đăng ký |
| POST | `/api/auth/login` | | 10/min | Đăng nhập |
| POST | `/api/auth/refresh` | | 10/min | Refresh token |
| POST | `/api/auth/logout` | 🔒 | | Đăng xuất |
| GET | `/api/homes` | 🔒 | | Danh sách nhà |
| POST | `/api/homes` | 🔒 | | Tạo nhà |
| PUT | `/api/homes/:id` | 🔒 | | Sửa nhà (owner/admin) |
| DELETE | `/api/homes/:id` | 🔒 | | Xóa nhà (owner) |
| POST | `/api/homes/:id/invite` | 🔒 | | Mời thành viên (owner/admin) |
| GET | `/api/homes/:homeId/rooms` | 🔒 | | Danh sách phòng |
| POST | `/api/homes/:homeId/rooms` | 🔒 | | Tạo phòng (owner/admin) |
| PUT | `/api/rooms/:id` | 🔒 | | Sửa phòng (owner/admin) |
| DELETE | `/api/rooms/:id` | 🔒 | | Xóa phòng (owner/admin) |
| POST | `/api/devices` | 🔒 | 20/min | Đăng ký device |
| GET | `/api/devices/announce/:mac` | 🔒 | | Kiểm tra device đã online |
| GET | `/api/devices` | 🔒 | | Danh sách device |
| PUT | `/api/devices/:id` | 🔒 | | Sửa device (member) |
| DELETE | `/api/devices/:id` | 🔒 | | Xóa device (owner/admin) |
| GET | `/api/devices/:id/shadow` | 🔒 | | Lấy shadow state |
| PUT | `/api/devices/:id/shadow/desired` | 🔒 | | Set desired state |
| POST | `/api/devices/:id/command` | 🔒 | 30/min | Gửi command |
| GET | `/api/devices/:id/commands` | 🔒 | | Lịch sử command |
| GET | `/api/devices/:id/telemetry` | 🔒 | | Dữ liệu cảm biến |

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

| HTTP Code | Ý nghĩa |
|-----------|---------|
| 400 | Thiếu / sai định dạng request |
| 401 | Chưa đăng nhập hoặc token hết hạn |
| 403 | Không có quyền (sai role hoặc không phải thành viên) |
| 404 | Không tìm thấy tài nguyên |
| 409 | Xung đột — email/device đã tồn tại |
| 429 | Rate limit — quá nhiều request |
| 503 | Server degraded — một hoặc nhiều dependency down |

### Role hệ thống

| Role | Quyền |
|------|-------|
| `owner` | Toàn quyền: xóa nhà, xóa device, mời thành viên, sửa nhà/phòng |
| `admin` | Sửa nhà, tạo/sửa/xóa phòng, mời thành viên, xóa device |
| `member` | Xem, gửi command, xem telemetry, đổi tên/chuyển phòng device |

Role được enforce bằng `CHECK (role IN ('owner', 'admin', 'member'))` trong DB.

### Device ID

Device ID = MAC address ESP32, **lowercase**, format `aa:bb:cc:dd:ee:ff`.  
Hàm `normalizeDeviceId()` validate regex `/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/` — trả `null` nếu invalid.

### Authorization Functions

| Function | Kiểm tra | Dùng cho |
|----------|---------|----------|
| `checkDeviceAccess(fastify, deviceId, userId)` | User là member của home sở hữu device | GET/PUT shadow, GET/POST command, GET telemetry |
| `checkMembership(fastify, homeId, userId)` | User là member của home (any role) | POST /devices, GET rooms |
| `requireRole(fastify, homeId, userId, ...roles)` | User có role cụ thể, throw 403 nếu không | DELETE home/device, PUT home, invite, CRUD rooms |

---

## 2. Auth — Xác thực

### `POST /api/auth/register`

Tạo tài khoản mới.

**Rate limit:** 10/phút/IP

**Request body:**

| Field | Type | Bắt buộc | Default |
|-------|------|:--------:|---------|
| `email` | string | ✓ | — |
| `password` | string | ✓ | — |
| `full_name` | string | | `null` |

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

| Error | Code | Message |
|-------|------|---------|
| Thiếu email/password | 400 | `"email and password required"` |
| Email đã tồn tại | 409 | `"Email already registered"` |

**Internal:** bcrypt hash (`BCRYPT_ROUNDS = 12`), email lowercase trước khi lưu.

---

### `POST /api/auth/login`

Đăng nhập.

**Rate limit:** 10/phút/IP

**Request body:**

| Field | Type | Bắt buộc |
|-------|------|:--------:|
| `email` | string | ✓ |
| `password` | string | ✓ |

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

| Error | Code | Message |
|-------|------|---------|
| Thiếu email/password | 400 | `"email and password required"` |
| Sai password hoặc `is_active=false` | 401 | `"Invalid credentials"` |

**Internal:**
- Access token: JWT, expiry 15m (`JWT_EXPIRES_IN`)
- Refresh token: UUID v4, expiry 30 ngày (`REFRESH_TOKEN_EXPIRES_DAYS`)
- INSERT `refresh_tokens` + SET Redis `session:{userId}` (TTL 30d)
- SET HttpOnly cookie `refreshToken` (SameSite: Strict, path: `/api/auth/refresh`)
- Body cũng chứa `refreshToken` cho mobile client (không dùng cookie)

---

### `POST /api/auth/refresh`

Lấy access token mới. Flutter Dio interceptor gọi tự động khi 401.

**Rate limit:** 10/phút/IP

**Request body** (hoặc HttpOnly cookie):

| Field | Type | Bắt buộc |
|-------|------|:--------:|
| `refreshToken` | string | ✓ (hoặc cookie) |

> Ưu tiên: `body.refreshToken` > `cookie.refreshToken`

**200 OK:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

| Error | Code | Message |
|-------|------|---------|
| Không gửi token | 401 | `"No refresh token"` |
| Token invalid/expired | 401 | `"Invalid or expired refresh token"` |

**Internal:**
1. Tìm token trong `refresh_tokens` (JOIN users), check `expires_at > NOW()`
2. **DELETE token cũ** — token rotation (mỗi token dùng 1 lần)
3. INSERT token mới + SET Redis + SET cookie
4. Issue access token mới

---

### `POST /api/auth/logout` 🔒

Đăng xuất toàn bộ session.

**200 OK:**
```json
{ "success": true }
```

**Internal:**
1. DELETE tất cả `refresh_tokens` theo `user_id` (logout everywhere)
2. DEL Redis `session:{userId}`
3. Clear cookie `refreshToken`

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

| Field | Type | Bắt buộc | Default |
|-------|------|:--------:|---------|
| `name` | string | ✓ | — |
| `address` | string | | `null` |
| `timezone` | string | | `"Asia/Ho_Chi_Minh"` |

**201 Created:** Home object.

| Error | Code | Message |
|-------|------|---------|
| Thiếu name | 400 | `"name required"` |

**Internal:** Transaction — INSERT `homes` + INSERT `home_members` (role='owner'). Rollback nếu một trong hai fail.

---

### `PUT /api/homes/:id` 🔒

Sửa nhà. **owner/admin**.

**Request body** (optional, COALESCE — field không gửi giữ nguyên):

| Field | Type |
|-------|------|
| `name` | string |
| `address` | string |
| `timezone` | string |

**200 OK:** Updated home object.

| Error | Code | Message |
|-------|------|---------|
| Không phải owner/admin | 403 | `"Forbidden"` |
| Home không tồn tại | 404 | `"Not found"` |

---

### `DELETE /api/homes/:id` 🔒

Xóa nhà. **Chỉ owner**.

**204 No Content.**

| Error | Code | Message |
|-------|------|---------|
| Không phải owner | 403 | `"Forbidden"` |

**Internal:** CASCADE — xóa home → tự động xóa devices, rooms, home_members.

---

### `POST /api/homes/:id/invite` 🔒

Mời thành viên bằng email. **owner/admin**.

**Request body:**

| Field | Type | Bắt buộc | Default |
|-------|------|:--------:|---------|
| `email` | string | ✓ | — |
| `role` | string | | `"member"` |

**200 OK:** `{ "success": true }`

| Error | Code | Message |
|-------|------|---------|
| Thiếu email | 400 | `"email required"` |
| Không phải owner/admin | 403 | `"Forbidden"` |
| Email chưa đăng ký | 404 | `"User not found"` |
| Đã là thành viên | 409 | `"Already a member"` |

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

| Error | Code | Message |
|-------|------|---------|
| Không phải thành viên | 403 | `"Forbidden"` |

---

### `POST /api/homes/:homeId/rooms` 🔒

Tạo phòng. **owner/admin**.

| Field | Type | Bắt buộc |
|-------|------|:--------:|
| `name` | string | ✓ |
| `icon` | string | |

**201 Created:** Room object.

| Error | Code | Message |
|-------|------|---------|
| Thiếu name | 400 | `"name required"` |
| Không phải owner/admin | 403 | `"Forbidden"` |

---

### `PUT /api/rooms/:id` 🔒

Sửa phòng. **owner/admin**.

| Field | Type |
|-------|------|
| `name` | string |
| `icon` | string |

**200 OK:** Updated room object.

| Error | Code | Message |
|-------|------|---------|
| Không phải owner/admin | 403 | `"Forbidden"` |
| Room không tồn tại | 404 | `"Not found"` |

**Internal:** Truy vấn `home_id` từ room, sau đó `requireRole()`.

---

### `DELETE /api/rooms/:id` 🔒

Xóa phòng. **owner/admin**. Devices trong phòng sẽ SET `room_id = NULL` (không bị xóa).

**204 No Content.**

| Error | Code | Message |
|-------|------|---------|
| Không phải owner/admin | 403 | `"Forbidden"` |
| Room không tồn tại | 404 | `"Not found"` |

---

## 5. Devices — Thiết bị

### `POST /api/devices` 🔒

Đăng ký ESP32 sau BLE provisioning.

**Rate limit:** 20/phút/IP

**Request body:**

| Field | Type | Bắt buộc | Validation |
|-------|------|:--------:|-----------|
| `device_id` | string | ✓ | MAC format `aa:bb:cc:dd:ee:ff` |
| `name` | string | ✓ | — |
| `home_id` | string (UUID) | ✓ | UUID regex |
| `room_id` | string (UUID) | | — |

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

| Error | Code | Message |
|-------|------|---------|
| Thiếu fields | 400 | `"device_id, name, home_id required"` |
| home_id sai format | 400 | `"home_id must be a valid UUID"` |
| Không phải thành viên home | 403 | `"Forbidden"` |
| Device đã tồn tại | 409 | `"Device already registered"` |

**Internal:**
1. `normalizeDeviceId()` — validate MAC + lowercase
2. `checkMembership()` — mọi thành viên đều đăng ký device được
3. Tìm `device_types` name `'smart_air_v1'`
4. Tạo `secret_key = uuidv4()`
5. INSERT `devices`
6. EMQX: tạo MQTT user + ACL rule `device/{id}/#` (warning nếu fail)

---

### `GET /api/devices/announce/:mac` 🔒

Kiểm tra ESP32 đã announce online chưa (polling sau BLE provisioning).

**200 OK:** `{ "announced": true }` hoặc `{ "announced": false }`

| Error | Code | Message |
|-------|------|---------|
| MAC invalid | 400 | `"Invalid mac"` |

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

| Field | Type |
|-------|------|
| `name` | string |
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

| Error | Code | Message |
|-------|------|---------|
| Invalid MAC | 400 | `"Invalid device ID"` |
| Không phải thành viên | 403 | `"Forbidden"` |
| Device không tồn tại | 404 | `"Not found"` |

---

### `DELETE /api/devices/:id` 🔒

Xóa device. **owner/admin** (via `requireRole`).

**204 No Content.**

| Error | Code | Message |
|-------|------|---------|
| Invalid MAC | 400 | `"Invalid device ID"` |
| Không phải owner/admin | 403 | `"Forbidden"` |
| Device không tồn tại | 404 | `"Not found"` |

**Internal:**
1. `requireRole('owner', 'admin')` trên home chứa device
2. DELETE `devices` (CASCADE xóa `device_shadows`, `commands`)
3. DEL Redis: `shadow:`, `pending_cmds:`, `announce:`, `ota_progress:`
4. EMQX: xóa user + ACL (warning nếu fail)

---

## 6. Shadow — Trạng thái thiết bị

Shadow = snapshot state gồm:
- **`reported`**: ESP32 tự báo (nhiệt độ, độ ẩm, firmware, timestamp)
- **`desired`**: App set (fan_speed, led, timer...)

Cache: Redis `shadow:{deviceId}` TTL 1h (`REDIS_TTL_SHADOW`), fallback DB `device_shadows`.

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

| Error | Code | Message |
|-------|------|---------|
| Invalid MAC | 400 | `"Invalid device ID"` |
| Không phải thành viên | 403 | `"Forbidden"` |

---

### `PUT /api/devices/:id/shadow/desired` 🔒

Authorization: `checkDeviceAccess()`

**Request body:** JSON object bất kỳ.

```json
{ "fan_speed": 3, "led": false }
```

**200 OK:** `{ "success": true }`

| Error | Code | Message |
|-------|------|---------|
| Body không phải object | 400 | `"body must be JSON object"` |
| Invalid MAC | 400 | `"Invalid device ID"` |
| Không phải thành viên | 403 | `"Forbidden"` |

**Internal:**
1. `setDesired()` — UPSERT DB (atomic) → DEL Redis cache (race-safe)
2. Nếu device online → MQTT publish `device/{id}/shadow/get_response`:
   ```json
   { "desired": { "fan_speed": 3, "led": false } }
   ```
3. Nếu offline → chỉ lưu DB, push khi device online lại (`handleStatus`)

---

## 7. Commands — Điều khiển

### `POST /api/devices/:id/command` 🔒

**Rate limit:** 30/phút/IP  
Authorization: `checkDeviceAccess()`

**Request body:**

| Field | Type | Bắt buộc |
|-------|------|:--------:|
| `payload` | object | ✓ |

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

| Error | Code | Message |
|-------|------|---------|
| Invalid MAC | 400 | `"Invalid device ID"` |
| Thiếu/sai payload | 400 | `"payload required"` |
| Không phải thành viên | 403 | `"Forbidden"` |

**Internal (device online):**
1. INSERT `commands` status=`pending`
2. MQTT publish `device/{id}/command`: `{ command_id, ...payload }`
3. UPDATE status=`sent`

**Internal (device offline):**
1. INSERT `commands` status=`pending`
2. RPUSH Redis `pending_cmds:{deviceId}`: `{ command_id, payload }`
3. Khi device online → `flushPending()` (atomic RENAME) gửi từng command

**Command lifecycle:** `pending` → `sent` → `done` | `failed`

> Status cuối do firmware quyết định. CHECK constraint: `('pending','sent','done','failed')`.

**Các lệnh thực tế:**

| Lệnh | Payload |
|------|---------|
| Đồng bộ thời gian | `{ "type": "set_time", "ts": 1777631761 }` |

> ESP32 nhận → thực thi → publish `device/{id}/response`: `{ command_id, status: "done" }`  
> Server `handleResponse()` → UPDATE `commands.status`, `executed_at = NOW()`.

---

### `GET /api/devices/:id/commands` 🔒

Lịch sử command, mới nhất trước. Authorization: `checkDeviceAccess()`

**Query params:**

| Param | Default | Max |
|-------|---------|-----|
| `limit` | 50 | 200 (`COMMANDS_MAX_LIMIT`) |
| `offset` | 0 | — |

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

| Error | Code | Message |
|-------|------|---------|
| Invalid MAC | 400 | `"Invalid device ID"` |
| Không phải thành viên | 403 | `"Forbidden"` |

---

## 8. Telemetry — Dữ liệu cảm biến

ESP32 publish mỗi 5s lên `device/{id}/telemetry`. Server `handleTelemetry()` INSERT vào TimescaleDB hypertable. Retention: 1 year.

### `GET /api/devices/:id/telemetry` 🔒

Authorization: `checkDeviceAccess()`

**Query params:**

| Param | Default | Max | Mô tả |
|-------|---------|-----|-------|
| `from` | 24h trước | — | ISO 8601 |
| `to` | Hiện tại | — | ISO 8601 |
| `limit` | 1000 | 5000 | Chỉ áp dụng raw mode |
| `agg` | _(none)_ | — | Whitelist: `1m`, `5m`, `15m`, `30m`, `1h`, `6h`, `1d` |

> Khi có `agg`: `time_bucket()` + AVG, **không áp dụng `limit`**.  
> Khi không có `agg`: raw data, áp dụng `limit`.

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

| Error | Code | Message |
|-------|------|---------|
| Invalid MAC | 400 | `"Invalid device ID"` |
| `agg` không hợp lệ | 400 | `"Invalid agg value. Allowed: 1m, 5m, 15m, 30m, 1h, 6h, 1d"` |
| Không phải thành viên | 403 | `"Forbidden"` |

**Flutter `fl_chart` guide:**

| Chart mode | `agg` | `limit` | `from` |
|-----------|-------|---------|--------|
| 1h realtime | _(none)_ | 720 | `now - 1h` |
| 24h | `1h` | _(omit)_ | `now - 24h` |
| 7 ngày | `6h` | _(omit)_ | `now - 7d` |
| 30 ngày | `1d` | _(omit)_ | `now - 30d` |

---

## 9. MQTT WebSocket — Realtime

```
URL:      wss://minhnhat05.xyz/mqtt
Protocol: MQTT v3.1.1 over WebSocket
```

> Nginx proxy `/mqtt` → EMQX port 8083.

> **Lưu ý:** Flutter app hiện dùng REST polling 10s (`shadowProvider`), chưa implement MQTT WebSocket client.

**Topics subscribe:**

| Topic | Payload | Dùng để |
|-------|---------|---------|
| `device/{id}/status` | `{"online":true,"firmware":"1.0.0"}` | Online/offline |
| `device/{id}/telemetry` | `{"device_id":"...","ts":123,"temperature":28.5,"humidity":65.2}` | Realtime sensor |
| `device/{id}/ota/progress` | `{"progress":50,"status":"downloading"}` | OTA progress |

---

## 10. Redis Keys Reference

| Key | Type | TTL | Set bởi |
|-----|------|-----|---------|
| `session:{userId}` | string | 30d | `issueRefreshToken()` |
| `announce:{deviceId}` | string | 300s | `handleStatus()` |
| `shadow:{deviceId}` | JSON string | 3600s | `getShadow()` (cache) |
| `pending_cmds:{deviceId}` | list | **none** | `sendCommand()` (offline) |
| `pending_cmds:{deviceId}:flushing` | list | transient | `flushPending()` (atomic rename) |
| `ota_progress:{deviceId}` | JSON string | 600s | `handleOtaProgress()` |

---

## 11. MQTT Bridge — Server-side

Client ID `sa-api-bridge`, kết nối `mqtt://emqx:1883` (internal Docker network).

**Subscribe:**

| Topic | Handler | Xử lý |
|-------|---------|-------|
| `device/+/status` | `handleStatus()` | UPDATE `devices.online` + `last_seen`; SET `announce:`; `flushPending()`; push desired shadow |
| `device/+/telemetry` | `handleTelemetry()` | INSERT TimescaleDB. `ts` = `payload.ts * 1000` hoặc `NOW()` |
| `device/+/response` | `handleResponse()` | UPDATE `commands.status` + `executed_at`. Status whitelist: `done`/`failed` (default `done`) |
| `device/+/shadow/report` | `updateReported()` | UPSERT `device_shadows` → DEL Redis cache |
| `device/+/ota/progress` | `handleOtaProgress()` | SET Redis TTL 600s |

**Publish:**

| Topic | Khi nào | Payload |
|-------|---------|---------|
| `device/{id}/command` | `sendCommand()` / `flushPending()` | `{ command_id, ...payload }` |
| `device/{id}/shadow/get_response` | Device online / `PUT /shadow/desired` | `{ desired: {...} }` |

---

## 12. Constants Reference

Tất cả centralized tại `src/constants.js`:

| Constant | Giá trị | Dùng cho |
|----------|---------|----------|
| `REDIS_TTL_ANNOUNCE` | 300 | TTL `announce:` key |
| `REDIS_TTL_OTA` | 600 | TTL `ota_progress:` key |
| `REDIS_TTL_SHADOW` | 3600 | TTL `shadow:` cache |
| `BCRYPT_ROUNDS` | 12 | Password hash strength |
| `REFRESH_COOKIE_PATH` | `/api/auth/refresh` | Cookie path |
| `SECONDS_PER_DAY` | 86400 | Refresh token expiry calc |
| `ALLOWED_ORIGINS` | `['https://minhnhat05.xyz']` | CORS (env override: `CORS_ORIGINS`) |
| `RATE_LIMIT_COMMAND` | 30/min | POST /command |
| `RATE_LIMIT_DEVICE` | 20/min | POST /devices |
| `AGG_ALLOWED` | `1m,5m,15m,30m,1h,6h,1d` | Telemetry agg whitelist |
| `COMMANDS_MAX_LIMIT` | 200 | Max limit query commands |
| `TELEMETRY_DEFAULT_LIMIT` | 1000 | Default limit telemetry |
| `TELEMETRY_MAX_LIMIT` | 5000 | Max limit telemetry |
| `MS_PER_DAY` | 86400000 | Default `from` (24h trước) |

---

## 13. Flows thực tế

### Flow 1 — BLE Provisioning → Device online

```
 1. ESP32 boot → BLE advertising "SMART_AIR_13ED8C"
 2. Flutter scan BLE → connect GATT
 3. Flutter write SSID → characteristic 0xFF01
 4. Flutter write Password → characteristic 0xFF02
 5. ESP32 kết nối WiFi → MQTT broker (mqtts://192.168.1.16:8883)
 6. ESP32 publish device/{mac}/status = {"online":true,"firmware":"1.0.0"}
 7. Server handleStatus() → UPDATE devices → SET announce:{mac} TTL 300s
 8. ESP32 notify Flutter qua 0xFF03: {"ip":"192.168.1.26","status":"ok"}
 9. Flutter POST /api/devices { device_id: mac, name, home_id }
10. Server tạo EMQX user + ACL → trả về secret_key
11. Flutter flash secret_key vào ESP32 (HTTP POST /api/config)
12. Flutter polling GET /api/devices/announce/{mac} → announced: true
13. Flutter navigate → device detail screen
```

### Flow 2 — Realtime Dashboard

```
1. Flutter mở device detail
2. GET /api/devices/:id/shadow → hiển thị temperature/humidity
3. Timer 10s: refresh shadow + invalidate devicesProvider (REST polling)
4. GET /api/devices/:id/telemetry?agg=1h → vẽ fl_chart
5. ESP32 disconnect → LWT publish device/{id}/status = {"online":false}
6. Server handleStatus() → UPDATE devices.online = false
7. Flutter refresh → offline badge + last_seen
```

### Flow 3 — Command set_time

```
1. Flutter POST /api/devices/:id/command { payload: { type: "set_time", ts: ... } }
2. Server INSERT commands status='pending'
3. Device online → MQTT publish device/{id}/command: { command_id, type, ts }
4. Server UPDATE status='sent'
5. ESP32 nhận → cập nhật DS3231 RTC
6. ESP32 publish device/{id}/response: { command_id, status: "done" }
7. Server handleResponse() → UPDATE status='done', executed_at=NOW()
8. Flutter GET /api/devices/:id/commands → status "done"
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

---

## 14. Error Reference

### Auth Errors

| Situation | Code | Body |
|-----------|------|------|
| Thiếu Authorization header | 401 | `{ "error": "Unauthorized" }` |
| Token hết hạn / invalid | 401 | `{ "error": "Unauthorized" }` |

### Permission Errors

| Situation | Code | Body |
|-----------|------|------|
| `checkDeviceAccess` / `checkMembership` fail | 403 | `{ "error": "Forbidden" }` |
| `requireRole` fail | 403 | Fastify: `{ "statusCode": 403, "error": "Forbidden", "message": "Forbidden" }` |

### Validation Errors

| Situation | Code | Message |
|-----------|------|---------|
| Thiếu email/password | 400 | `"email and password required"` |
| Thiếu name (home/room) | 400 | `"name required"` |
| Thiếu email (invite) | 400 | `"email required"` |
| Thiếu device fields | 400 | `"device_id, name, home_id required"` |
| home_id sai UUID | 400 | `"home_id must be a valid UUID"` |
| Device ID sai MAC | 400 | `"Invalid device ID"` hoặc `"Invalid mac"` |
| Thiếu command payload | 400 | `"payload required"` |
| Shadow body sai format | 400 | `"body must be JSON object"` |
| Telemetry agg sai | 400 | `"Invalid agg value. Allowed: 1m, 5m, 15m, 30m, 1h, 6h, 1d"` |

### Conflict Errors

| Situation | Code | Message |
|-----------|------|---------|
| Email đã đăng ký | 409 | `"Email already registered"` |
| Device đã tồn tại | 409 | `"Device already registered"` |
| Đã là thành viên | 409 | `"Already a member"` |

### Infrastructure Errors

| Situation | Code | Body |
|-----------|------|------|
| DB/Redis/MQTT down | 503 | `{ "status": "degraded", "ts": ..., "checks": { "postgres": "fail", ... } }` |
| Rate limit exceeded | 429 | `{ "statusCode": 429, "error": "Too Many Requests", ... }` |
