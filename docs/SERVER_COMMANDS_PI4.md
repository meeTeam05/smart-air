# Server Setup & Commands for Raspberry Pi 4

Tài liệu này tổng hợp tất cả các câu lệnh và hướng dẫn để triển khai, chạy, và kiểm tra hệ thống server của dự án **smart-air** trên Raspberry Pi 4. Server được chạy hoàn toàn bằng Docker, bao gồm Nginx, EMQX, Node.js API (Fastify), PostgreSQL (TimescaleDB), Redis, Grafana, Portainer và pgAdmin.

---

## 1. Triển khai Server (Docker Compose)

Đầu tiên, bạn cần di chuyển vào thư mục chứa cấu hình Docker của dự án:

```bash
cd server/
```

### Chạy tất cả các dịch vụ (chạy ngầm)

```bash
docker compose up -d
```

### Dừng tất cả các dịch vụ

```bash
docker compose down
```

### Khởi động lại các dịch vụ

```bash
docker compose restart
```

---

## 2. Kiểm tra trạng thái Server

### Xem danh sách các container đang chạy

Lệnh này giúp bạn kiểm tra xem các container (nginx, emqx, api, postgres, redis, grafana...) có đang hoạt động (Up) hay không:

```bash
docker compose ps
```

### Xem log hệ thống

Nếu có dịch vụ nào gặp lỗi, bạn có thể xem log tổng hoặc log của riêng biệt từng dịch vụ:

- Xem log tất cả các dịch vụ (theo dõi trực tiếp):
  ```bash
  docker compose logs -f
  ```
- Xem log riêng của Nginx (Reverse Proxy):
  ```bash
  docker compose logs -f nginx
  ```
- Xem log riêng của API server (Node.js/Fastify):
  ```bash
  docker compose logs -f api
  ```
- Xem log riêng của EMQX (MQTT Broker):
  ```bash
  docker compose logs -f emqx
  ```

---

## 3. Cấu hình Database & API

Sau khi các container đã `Up`, bạn cần chạy migration để tạo schema cho database PostgreSQL dựa trên thiết kế ban đầu (`001_initial_schema.sql` và `002_device_id_text.sql`).

### Chạy DB Migration

Mở một terminal riêng, di chuyển sang thư mục API và chạy migration:

```bash
cd server/api
npm install
npm run migrate
```

### Kiểm tra sức khỏe API

Kiểm tra xem Nginx cấu hình đúng và API backend đã sẵn sàng chưa bằng lệnh sau (trên Pi hoặc các máy tính trong local):

```bash
curl http://localhost/api/health
# Hoặc thay bằng địa chỉ IP của Pi (Ví dụ: 192.168.1.16)
curl http://<IP_CỦA_PI>/api/health
```

_(Bạn sẽ nhận được Status HTTP 200 OK)_

---

## 4. Các tính năng & Cổng dịch vụ liên quan

Khi deploy thành công, hệ thống sẽ tự động map các dịch vụ qua các cổng sau dựa vào cấu trúc của `docker-compose.yml` và phân luồng qua Nginx:

| Dịch vụ / Tính năng     | Truy cập qua mạng nội bộ     | Chú thích                                                   |
| :---------------------- | :--------------------------- | :---------------------------------------------------------- |
| **Node.js REST API**    | `http://<IP_CỦA_PI>/api/*`   | API quản lý Auth, Devices, Homes, Telemetry...              |
| **MQTT TLS (Thiết bị)** | `mqtts://<IP_CỦA_PI>:8883`   | ESP32 publish/subscribe trực tiếp qua cổng bảo mật `8883`   |
| **MQTT WebSockets**     | `ws://<IP_CỦA_PI>/ws`        | Flutter app gọi realtime update bằng WSS qua Nginx          |
| **Grafana**             | `http://<IP_CỦA_PI>/grafana` | Bảng điều khiển giám sát Metric và Telemetry theo thời gian |
| **Portainer**           | Kênh nội bộ cổng `9000`      | UI quản lý Docker container (_nếu phơi ra ngoài_)           |
| **EMQX Dashboard**      | Kênh nội bộ cổng `18083`     | UI để theo dõi trạng thái thiết bị và các kết nối MQTT      |

### Kiểm tra tính năng MQTT

Từ Pi hoặc máy dev, bạn có thể kiểm tra xem MQTT broker (EMQX) có hoạt động bằng mosquitto*pub/sub. *(Bạn cần cung cấp tên thiết bị & mật khẩu secret*key nếu đã bật Per-device Authentication).*

- Lệnh tải cấu hình cho phép thiết bị test:
  ```bash
  mosquitto_sub -h localhost -p 8883 -t "device/+/status" --cafile <path_to_ca_cert> -d
  ```

## 5. Đồng bộ Database khi mất dữ liệu (Sự cố)

Nếu bạn lỡ xoá container DB hoặc cần chạy lại db backup, có thể dùng câu lệnh pg_dump/restore hoặc gắn file init sql vào thư mục config tuỳ theo Docker schema. Theo architecture, backup sẽ thông qua:

```bash
# Ví dụ Backup DB
docker exec -t <postgres_container_name> pg_dump -U username dbname > backup.sql
```

## 6. Truy cập từ xa (Cloudflare Tunnel)

**Domain:** `minhnhat05.xyz` (Namecheap)

Infrastructure đã chuẩn — chỉ cần lấy token và chạy container. Làm theo 4 bước:

### Bước 6.1 — Thêm domain vào Cloudflare

1. Đăng nhập [cloudflare.com](https://cloudflare.com) → **Add a Site** → nhập `minhnhat05.xyz` → chọn **Free**
2. Cloudflare sẽ hiện 2 nameserver (ví dụ `alice.ns.cloudflare.com` và `bob.ns.cloudflare.com`)
3. Ghi lại 2 nameserver này — cần cho bước tiếp theo

### Bước 6.2 — Đổi Nameserver trên Namecheap

1. Đăng nhập [Namecheap](https://namecheap.com) → **Domain List** → `minhnhat05.xyz` → **Manage**
2. Tab **Nameservers** → chọn **Custom DNS**
3. Nhập 2 nameserver từ bước 6.1 → **Save** (biểu tượng ✓)
4. Chờ propagation: thường 15–60 phút, tối đa 24h

### Bước 6.3 — Tạo Cloudflare Tunnel và lấy token

1. Trong Cloudflare Dashboard → **Zero Trust** (menu trái) → **Networks** → **Tunnels**
2. **Create a tunnel** → Connector type: **Cloudflared** → tên: `smart-air-pi` → **Save tunnel**
3. Tại trang Install connector → chọn tab **Docker** → copy chuỗi token dài sau `--token` trong lệnh `docker run`
4. Chuyển sang tab **Public Hostname** → **Add a public hostname**:
   - **Subdomain:** _(để trống)_, **Domain:** `minhnhat05.xyz`, **Service:** `http://sa-nginx:80` → Save
5. _(Tùy chọn)_ Thêm hostname thứ hai: **Subdomain:** `www`, **Domain:** `minhnhat05.xyz`, **Service:** `http://sa-nginx:80`

### Bước 6.4 — Khởi động cloudflared trên Pi

```bash
# SSH vào Pi
ssh nhat@192.168.1.16

# Mở file .env, thêm token
cd ~/Working_Space/smart-air/server
nano .env
# Tìm dòng CLOUDFLARE_TUNNEL_TOKEN= và điền token vào

# Khởi động cloudflared container (đã được định nghĩa trong docker-compose.yml)
docker compose up -d cloudflared

# Kiểm tra logs
docker compose logs -f cloudflared
# Khi thấy: "Connection established" và "Registered tunnel connection" → thành công
```

### Bước 6.5 — Verify

```bash
# Từ máy tính bất kỳ (ngoài LAN)
curl https://minhnhat05.xyz/api/health
# → {"status":"ok"}

# Hoặc mở trình duyệt
# https://minhnhat05.xyz/api/health      → API
# https://minhnhat05.xyz/grafana/        → Grafana dashboard
```

### Các đường dẫn sau khi setup xong

| Dịch vụ | URL bên ngoài LAN |
|---------|-------------------|
| REST API | `https://minhnhat05.xyz/api/*` |
| MQTT WebSocket (Flutter) | `wss://minhnhat05.xyz/mqtt` |
| Grafana | `https://minhnhat05.xyz/grafana/` |
| OTA firmware files | `https://minhnhat05.xyz/ota/<file>.bin` |

**Lưu ý quan trọng:**
- **ESP32 MQTT** vẫn dùng `mqtts://192.168.1.16:8883` (local — không thay đổi firmware)
- **ESP32 OTA** vẫn dùng `https://192.168.1.16/ota/...` (local self-signed cert — CA cert trong firmware cần cập nhật mới dùng domain được)
- **EMQX Dashboard** (`192.168.1.16:18083`) và **pgAdmin** (`192.168.1.16:5050`) không expose ra ngoài (chỉ LAN)

---

## 7. Hướng dẫn Test Firmware OTA (Thủ công)

Khi chưa có tính năng OTA tự động trên App, bạn có thể trigger OTA thủ công thông qua broker MQTT dưới quyền Admin.

### Bước 1: Build Firmware và Copy sang Server (Raspberry Pi)

Mở một **Terminal/Powershell mới** trên máy tính cá nhân tính của bạn (không gõ trên terminal đang SSH sang Pi), chạy lệnh `scp` (Secure Copy) để sao chép file `.bin` đã build:

```bash
scp E:\my-project\smart-air\firmware\build\smart-air.bin nhat@192.168.1.16:~/Working_Space/smart-air/server/ota-files/
```
*(Nếu thành công, Nginx sẽ tự động host file này ở địa chỉ `https://192.168.1.16/ota/smart-air.bin`)*

### Bước 2: Lấy mã băm SHA-256
Trên terminal của Pi, gõ lệnh sau để lấy khóa kiểm tra tính toàn vẹn (SHA-256) của file:

```bash
sha256sum ~/Working_Space/smart-air/server/ota-files/smart-air.bin
```
Copy lại chuỗi dài mã băm bao gồm toán các số và ký tự được in ra.

### Bước 3: Đánh tín hiệu kích hoạt cập nhật (Trigger OTA qua Web Dashboard - Dễ nhất)

Thay vì phải tạo API Key để dùng qua lệnh curl, cách dễ và trực quan nhất là dùng công cụ test MQTT có sẵn trong web quản trị của EMQX:

1. Mở trình duyệt vào trang quản trị: `http://192.168.1.16:18083`
2. Đăng nhập với ID: `admin`, Password: `smart-air`
3. Tìm mục **WebSocket Client** (bên menu trái).
4. Để nguyên giá trị mặc định, bấm **Connect**.
5. Kéo xuống mục **Publish**:
   - **Topic**: `device/<DEVICE_ID_CỦA_BẠN>/ota/update` 
     *(NHẮC LẠI: Phải là địa chỉ MAC của ESP32, ví dụ `dc:b4:d9:13:ed:8c`, TUYỆT ĐỐI không điền IP `192.168.1.16` vào đây!)*
   - **Payload**:
     ```json
     {
       "url": "https://192.168.1.16/ota/smart-air.bin",
       "sha256": "<CHUỖI_SHA_256_COPY_Ở_BƯỚC_2>"
     }
     ```
    - **Payload**: `{"url":"https://192.168.1.16/ota/smart-air.bin", "sha256":"8d5747c52068034858c73cea41923249e3a5830770fb6d590c43cf3abd4a3a1a"}`
6. Bấm nút **Publish**.

Thiết bị ESP32 của bạn sẽ tiến hành nhận gói tin, tải firmware mới và tự động khởi động.

---

## 8. Hướng dẫn Xem và Quản trị Database (pgAdmin)

Hệ thống cung cấp sẵn pgAdmin với giao diện trực quan để xem toàn bộ dữ liệu đang lưu trong cấu trúc PostgreSQL (TimescaleDB).

1. Mở trình duyệt, truy cập vào trang quản trị: `http://<IP_PI>:5050` (Ví dụ: `http://192.168.1.16:5050`)
2. Đăng nhập bằng tài khoản quản trị (đã cấu hình mặc định trong `.env`):
   - **Email:** `admin@smartair.local`
   - **Password:** `smart-air`
3. Tại giao diện chính, thao tác kết nối với Database Container Server:
   - Nhấn nút **Add New Server**.
   - Chuyển sang Tab **General**: Đặt tên Server theo ý bạn (VD: `smart-air-db`).
   - Chuyển sang Tab **Connection**:
     - **Host name/address**: `postgres` *(lưu ý gõ đúng chữ postgres, đây là tên nội bộ của DB trong container)*.
     - **Port**: `5432`
     - **Username**: `smartair`
     - **Password**: `smart-air`
   - Bấm **Save**.
4. 📂 **Xem dữ liệu Cảm biến (Telemetry):**
   - Ở thanh điều hướng bên trái, bạn bấm xổ chuột mở dần hệ thống bằng cách theo nhánh sau: `Servers -> smart-air-db -> Databases -> smartair -> Schemas -> public -> Tables`.
   - Tìm đến bảng mang tên **`telemetry`**, bấm chuột phải chọn **View/Edit Data -> All Rows**. Bạn sẽ thấy lịch sử khổng lồ ghi chép toàn bộ các thông số đo được của hệ thống nhúng mà mạch ESP tự gửi về.

---

## 9. Hướng dẫn Test Luồng API Backend (Dùng Postman)

Do các cổng kết nối của giao thức REST API này được thiết kế theo tiêu chuẩn bảo mật xác thực (yêu cầu gửi Authorization Token ở mọi Request), bạn nên sử dụng ứng dụng kiểm thử thư viện **Postman** (cài trên máy tính) để thao tác tốt nhất. 

### Bước 9.1: Tạo User và Xác thực
- **Đăng ký tài khoản (Register):**
  - **Phương thức:** `POST` - `http://<IP_PI>/api/auth/register`
  - **Body (chọn chế độ Raw -> JSON):**
    ```json
    { "email": "test@demo.com", "password": "123", "full_name": "Test User" }
    ```
- **Đăng nhập lấy Token (Login):**
  - **Phương thức:** `POST` - `http://<IP_PI>/api/auth/login`
  - **Body (chọn chế độ Raw -> JSON):** 
    ```json
    { "email": "test@demo.com", "password": "123" }
    ```
  - *Bạn sẽ nhận được một khối code dài trong đối tượng `accessToken`. Copy lấy nó để sang bước sau làm vé thông hành tiếp theo.*

### Bước 9.2: Bảo mật liên kết - Gán quyền sở hữu mạch
Trong cấu trúc kỹ thuật hạ tầng, nếu một người lạ gọi vào API Telemetry cũng không check được đâu vì User Account vừa tạo chưa hề có đặc quyền liên kết (Owner/Home Member) với cái mạch ESP32 kia. Hãy gắn mạch cho chủ nhân theo lệnh cấp quyền:

*⚠ LƯU Ý TRÊN POSTMAN: Ở các API từ bước này trở đi, bạn phải mở qua tab **Headers** thêm vào 1 thuộc tính: Key là `Authorization` và Value là `Bearer <DÁN_CÁI_CHUỖI_ACCESS_TOKEN_CỦA_BƯỚC_9.1_VÀO_ĐÂY>`.*

- **Tạo một nhóm Nhà:**
  - **Phương thức:** `POST` - `http://<IP_PI>/api/homes`
  - **Body:** `{"name": "Nhà Vui Vẻ", "address": "Bình Thạnh"}`
  - *Gửi request xong, server sẽ tạo 1 nhà và cấp cho bạn 1 mã gọi là `id` (home_id).*

- **Đăng ký thiết bị ESP32 (Gán vào nhà):**
  - **Phương thức:** `POST` - `http://<IP_PI>/api/devices`
  - **Body:** 
    ```json
    { "home_id": "<MÃ_NHÀ_ID_Ở_TRÊN>", "name": "Cảm biến phòng ngủ", "id": "<ĐỊA_CHỈ_MAC_CỦA_ESP32>" }
    ```

### Bước 9.3: Truy xuất API Dữ liệu (Telemetry)
Sau khi kết cấu bảo mật xác thực xong xuôi, bạn tiến hành Query dữ liệu ra frontend:
- **Phương thức:** `GET` - `http://<IP_PI>/api/devices/<ĐỊA_CHỈ_MAC_CỦA_ESP32>/telemetry?limit=5`
- *(Nhớ vẫn phải gắn Header là Authorization - Bearer Token như Bước 9.2 nha).*
- Hit Send gửi lên, Data từ DB sẽ được query nhả ra chính xác dưới dạng cấu trúc JSON chứa 5 dòng dữ liệu không khí mới nhất vừa đo! 


