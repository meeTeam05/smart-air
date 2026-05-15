# smart-air

![ESP32-S3](https://img.shields.io/badge/MCU-ESP32--S3-E7352C)
![ESP-IDF 5.4.2](https://img.shields.io/badge/ESP--IDF-5.4.2-111827)
![Flutter >=3.10](https://img.shields.io/badge/Flutter-%3E%3D3.10-02569B)
![Node.js 20](https://img.shields.io/badge/Node.js-20-339933)
![License MIT](https://img.shields.io/badge/License-MIT-22C55E)

![Smart-Air](assets/hero.png)

## Introduction

`smart-air` is an ESP32-S3 indoor air quality monitor and smart home controller. It combines ESP-IDF firmware, a Fastify + EMQX + PostgreSQL/TimescaleDB server stack, and a Flutter mobile app to solve device onboarding, telemetry ingestion, remote control, and live state sync in one system.

The device uses BLE for Wi-Fi provisioning, then publishes telemetry and shadow updates over MQTT. The app uses REST for snapshots, history, commands, and provisioning steps, and receives live updates from the API over Server-Sent Events at `GET /api/realtime`.

## Features

- ESP32-S3 firmware on ESP-IDF with BLE provisioning, Wi-Fi, MQTT, OTA hooks, sensor polling, display control, and relay control.
- Fastify API with PostgreSQL/TimescaleDB, Redis, and EMQX in Docker Compose.
- Device registration flow that provisions per-device MQTT credentials through the API.
- Realtime app updates over SSE, with REST kept as the canonical path for snapshots, history, replay, and fallback.
- Flutter app with Riverpod state management, auth flow, provisioning flow, device dashboards, and telemetry/history views.

## Prerequisites

- Flutter `>=3.10.0`
- Dart SDK `>=3.0.0 <4.0.0`
- Node.js `20` for the API image and local Node-based tooling
- Docker Engine with `docker compose` support for the server stack
- ESP-IDF `v5.4.2`
- Hardware:
  - ESP32-S3 board
  - SHT3x temperature/humidity sensor
  - DS3231 RTC
  - ILI9225 display on `SPI2_HOST`
  - SD card on `SPI3_HOST`
  - CO and NO2 analog sensors on `ADC1`
  - Android or iOS phone with BLE for provisioning

## Quick start

1. Start server stack.

```bash
cd server
cp .env.example .env
# fill in required secrets, passwords, and tunnel token in server/.env
docker compose up -d --build
```

2. Run mobile app.

```bash
cd app
flutter pub get
flutter run
```

If you are not using the default public endpoint, pass a custom API URL:

```bash
flutter run --dart-define=API_BASE_URL=https://<your-host>/api
```

3. Build and flash firmware.

```bash
cd firmware
. $HOME/.espressif/v5.4.2/esp-idf/export.sh
idf.py build flash monitor
```

4. Open the app, complete BLE Wi-Fi provisioning, register the device, and wait for live updates through `/api/realtime`.

## Contributing

- Read [AGENTS.md](AGENTS.md) before making changes.
- For structural work, also read `docs/ARCHITECTURE.md`, `docs/MQTT_PROTOCOL.md`, and `docs/API_REFERENCE.md`.
- Keep changes narrow, update matching docs when contracts change, and run the narrowest verification for the area you touched.

## License

MIT. See [LICENSE.md](LICENSE.md).
