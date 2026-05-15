# ARCHITECTURE.md

## Mục tiêu

Tài liệu này mô tả kiến trúc của hệ thống `smart-air`.
Phạm vi của tài liệu chỉ gồm kiến trúc hệ thống, kiến trúc thiết bị, ranh giới thành phần, và các bus kết nối chính.

## Kiến trúc tổng thể

`smart-air` là một hệ thống IoT gồm bốn khối chính:

1. Thiết bị biên dùng ESP32-S3 để đo môi trường, hiển thị trạng thái, lưu cục bộ, và giao tiếp mạng.
2. MQTT broker làm kênh đồng bộ trạng thái và vận chuyển telemetry/command giữa thiết bị và cloud.
3. API server làm ranh giới HTTP cho ứng dụng di động và điều phối nghiệp vụ phía server.
4. Ứng dụng Flutter làm lớp điều khiển và quan sát cho người dùng cuối.

Kiến trúc logic:

```text
+-------------------+        HTTPS         +-------------------+
|   Flutter App     | <------------------> |    API Server     |
+-------------------+                      +---------+---------+
                                                     |
                                                     | internal services
                                                     v
                                           +---------+---------+
                                           |   Data / Cache    |
                                           +---------+---------+
                                                     ^
                                                     |
                                                     | MQTT bridge / state sync
+-------------------+        MQTT/TLS       +--------+---------+
|   ESP32-S3 Node   | <------------------>  |   MQTT Broker    |
+-------------------+                       +------------------+
```

## Luồng provisioning và cấp quyền MQTT

Thiết bị mới không được thêm thủ công trong EMQX dashboard, và cũng không tự xuất hiện trong EMQX chỉ vì vừa bật nguồn hoặc vừa kết nối Wi-Fi.

User MQTT cho từng thiết bị được tạo bởi backend trong lúc ứng dụng di động gọi API đăng ký thiết bị.

Luồng thực tế:

```text
+-------------------+
|   ESP32-S3 Node   |
| device_id = MAC   |
+---------+---------+
          |
          | BLE / local provisioning info
          v
+---------+---------+          HTTPS           +-------------------+
|   Flutter App     | ----------------------> |    API Server     |
+---------+---------+   POST /api/devices     +---------+---------+
          ^                                              |
          |                                              | 1. validate home / role
          |                                              | 2. create secret_key
          |                                              | 3. create EMQX auth user = device_id
          |                                              | 4. create per-device ACL
          |                                              | 5. insert row into devices
          |                                              v
          |                                    +---------+---------+
          |                                    |    MQTT Broker    |
          |                                    |      EMQX         |
          |                                    +---------+---------+
          |                                              ^
          |                                              |
          | secret_key returned to app                   | MQTT/TLS
          +----------------------------------------------+
                         app passes credential to device
```

Trình tự nghiệp vụ:

1. Ứng dụng lấy `device_id` của thiết bị, tức MAC address chuẩn hóa dạng `aa:bb:cc:dd:ee:ff`.
2. Ứng dụng gọi `POST /api/devices` với `device_id`, `name`, `home_id`, và `room_id` nếu có.
3. API tạo `secret_key` ngẫu nhiên cho thiết bị.
4. API gọi EMQX Admin API để tạo user built-in database với:
   - `username = device_id`
   - `password = secret_key`
5. API tạo ACL per-device để thiết bị chỉ publish/subscribe đúng topic của chính nó.
6. Nếu bước EMQX thành công, API mới insert bản ghi vào bảng `devices`.
7. API trả `secret_key` về ứng dụng để ứng dụng chuyển credential đó xuống firmware qua local device provisioning.
8. Từ thời điểm này thiết bị mới có thể đăng nhập MQTT broker bằng credential riêng.

Hệ quả kiến trúc:

- User `sa-server` là bridge user của API server, không đại diện cho thiết bị biên.
- Nếu chưa có lời gọi `POST /api/devices`, EMQX chỉ cần có `sa-server` là đúng.
- Nếu tạo user EMQX thất bại, API không lưu thiết bị vào database.
- Nếu lưu database thất bại sau khi vừa tạo user EMQX, backend chạy cleanup để xóa user vừa tạo, tránh để lại orphan.
- Bước chuyển `secret_key` từ app xuống firmware là bắt buộc trước lần MQTT login đầu tiên. Firmware hỗ trợ local `POST http://<device-ip>/api/config` để validate `device_id` trùng MAC thật, lưu `secret_key`, và nếu có `broker_uri` thì ghi override vào NVS; nếu không thì xóa override cũ và dùng Kconfig default, sau đó reboot để kết nối MQTT bằng credential mới.
- Factory reset vật lý phải xóa toàn bộ trạng thái firmware trong NVS mặc định, gồm Wi-Fi provisioning, MQTT `secret_key`/`broker_uri`, device mode, và calibration gas.

## Bề mặt truy cập runtime

Các service cloud trong repo không cùng kiểu exposure:

- `emqx` publish `127.0.0.1:18083` cho dashboard/admin và `0.0.0.0:8883` như một direct MQTT/TLS override path.
- `pgadmin` publish `127.0.0.1:5050`.
- `portainer` publish `127.0.0.1:9000`.
- `api`, `nginx`, `grafana`, và `redis` không bind port trực tiếp ra host trong `docker-compose.yml`.
- `grafana` được thiết kế đi qua `nginx` tại path `/grafana/`, rồi qua Cloudflare Tunnel ở domain public.
- `api` được thiết kế đi qua `nginx` tại path `/api/`, rồi qua Cloudflare Tunnel ở domain public.
- Public path chuẩn cho firmware/app MQTT là `wss://minhnhat05.xyz/mqtt` qua Cloudflare Tunnel -> `nginx` -> EMQX WebSocket `8083`, nên không phụ thuộc NAT hay port forwarding ở router.
- Listener `8883` vẫn tồn tại như một direct `mqtts://` override path khi operator thật sự có public TCP và chứng chỉ phù hợp cho hostname đó.

Hệ quả vận hành:

- Truy cập local admin trực tiếp dùng các URL localhost đã publish.
- Truy cập `Grafana` và `API` theo thiết kế chuẩn là qua public path được reverse proxy, không phải `https://127.0.0.1/...`.

## Phân lớp trong thiết bị

Thiết bị biên được tổ chức theo các lớp sau:

1. `Application layer`
   Điều phối luồng đo đạc, cập nhật hiển thị, đồng bộ dữ liệu, và xử lý lệnh điều khiển.
2. `Device services layer`
   Gom các dịch vụ dùng chung như Wi-Fi, MQTT, lưu cấu hình, logging, và quản lý trạng thái thiết bị.
3. `Driver layer`
   Bao bọc từng ngoại vi và từng bus phần cứng.
4. `Hardware layer`
   ESP32-S3, cảm biến, màn hình, thẻ nhớ, và các khối I/O.

Sơ đồ khối:

```text
+--------------------------------------------------------------+
|                     Application Layer                        |
|  telemetry | control | display update | local storage flow   |
+------------------------------+-------------------------------+
                               |
+------------------------------v-------------------------------+
|                    Device Services Layer                     |
|  Wi-Fi  |  MQTT  |  config/NVS  |  state  |  logging         |
+------------------------------+-------------------------------+
                               |
+------------------------------v-------------------------------+
|                        Driver Layer                          |
|     I2C drivers     |     SPI drivers     |   ADC drivers    |
+------------------------------+-------------------------------+
                               |
+------------------------------v-------------------------------+
|                       Hardware Layer                         |
|  ESP32-S3 | SHT3x | DS3231 | ILI9225 | SD Card | gas sensors |
+--------------------------------------------------------------+
```

## Kiến trúc phần cứng thiết bị

Thiết bị tập trung quanh một MCU `ESP32-S3`, các bus ngoại vi dùng chung, và các khối cảm biến/hiển thị/lưu trữ tách biệt theo vai trò.

### Khối xử lý trung tâm

- `ESP32-S3` là bộ điều khiển trung tâm.
- MCU chịu trách nhiệm đọc cảm biến, dựng dữ liệu trạng thái, giao tiếp mạng, và điều phối các ngoại vi.

### Khối cảm biến

- `SHT3x` cung cấp nhiệt độ và độ ẩm.
- `DS3231` cung cấp thời gian thực.
- Hệ thống có thêm hai kênh cảm biến khí analog:
  - một kênh khí `CO`
  - một kênh khí `NO2`

### Khối hiển thị và lưu trữ

- Màn hình dùng `ILI9225`.
- Thẻ nhớ `SD Card` là khối lưu trữ cục bộ riêng.

## Kiến trúc bus

Thiết bị dùng ba bus chính, mỗi bus phục vụ một nhóm ngoại vi riêng:

### I2C bus

- `I2C` là bus cảm biến số dùng chung.
- `SHT3x` và `DS3231` cùng nằm trên bus này.
- Bus này phục vụ nhóm ngoại vi cần trao đổi dữ liệu điều khiển/trạng thái tuần tự, băng thông thấp.

### SPI bus cho hiển thị

- `SPI2_HOST` dành cho màn hình `ILI9225`.
- Bus này tách riêng cho khối hiển thị.

### SPI bus cho lưu trữ

- `SPI3_HOST` dành cho `SD Card`.
- Thẻ nhớ không dùng chung host SPI với màn hình.
- Cách tách này giữ cho khối hiển thị và khối lưu trữ độc lập về mode và nhịp truyền.

### ADC bus cho cảm biến khí

- `ADC1` dành cho các cảm biến khí analog.
- Hai kênh analog được tách riêng cho:
  - cảm biến `CO`
  - cảm biến `NO2`

Sơ đồ bus:

```text
                    +------------------+
                    |     ESP32-S3     |
                    +----+----+----+---+
                         |    |    |
           +-------------+    |    +-------------------+
           |                  |                        |
           v                  v                        v
      +----+----+        +----+-----+            +-----+------+
      |   I2C   |        | SPI2_HOST|            |    ADC1    |
      +----+----+        +----+-----+            +-----+------+
           |                  |                        |
     +-----+-----+       +----+----+            +------+------+
     |           |       | ILI9225 |            |             |
  +--+--+    +---+---+   +---------+         +--+--+      +---+---+
  |SHT3x|    |DS3231 |                     |  CO |      |  NO2  |
  +-----+    +-------+                     +-----+      +-------+

                    +------------------+
                    |    SPI3_HOST     |
                    +--------+---------+
                             |
                         +---+---+
                         |SD Card|
                         +-------+
```

## Kiến trúc phần mềm hệ thống

Mã nguồn được chia theo ranh giới kiến trúc như sau:

- `firmware/`
  Chứa toàn bộ phần mềm chạy trên ESP32-S3, gồm core system, services, drivers, và tác vụ thiết bị.
- `server/api/`
  Chứa API server và nghiệp vụ phía cloud.
- `server/`
  Chứa hạ tầng triển khai, broker, cache, database, và wiring giữa các dịch vụ backend.
- `app/`
  Chứa ứng dụng Flutter cho iOS và Android.
- `docs/`
  Chứa tài liệu kiến trúc, giao thức, và tài liệu tham chiếu hệ thống.

## Ranh giới thành phần

Các thành phần giao tiếp với nhau qua ranh giới rõ ràng:

- Thiết bị và broker giao tiếp qua `MQTT/TLS`.
- Ứng dụng di động và API server giao tiếp qua `HTTP(S)`.
- API server và broker phối hợp để phản chiếu trạng thái thiết bị và chuyển lệnh điều khiển.
- Thiết bị tách ba miền phần cứng chính:
  - miền cảm biến số trên `I2C`
  - miền hiển thị trên `SPI2_HOST`
  - miền lưu trữ trên `SPI3_HOST`

## Tóm tắt kiến trúc

`smart-air` là kiến trúc nhiều lớp, trong đó ESP32-S3 là nút biên trung tâm; `SHT3x`, `DS3231`, cảm biến khí `CO` và `NO2`, màn hình `ILI9225`, và `SD Card` được nối qua các bus tách biệt theo vai trò; phía cloud gồm MQTT broker, API server, và lớp dữ liệu; ứng dụng Flutter là lớp giao tiếp người dùng ở đầu cuối.
