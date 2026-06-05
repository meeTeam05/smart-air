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

## Hardware

### Schematic

![Schematic](assets/hardware/schematic.jpg)

### PCB Layout

<p align="center">
  <img src="assets/hardware/pcb-f.jpg" alt="PCB Front" width="48%">
  <img src="assets/hardware/pcb-b.jpg" alt="PCB Back" width="48%">
</p>

### 3D Model

<p align="center">
  <img src="assets/hardware/3d-f.jpg" alt="PCB Front" width="48%">
  <img src="assets/hardware/3d-b.jpg" alt="PCB Back" width="48%">
</p>

### Assembly

<p align="center">
  <img src="assets/hardware/real-a.jpg" alt="Assembly View A" width="31%">
  <img src="assets/hardware/real-b.jpg" alt="Assembly View B" width="31%">
  <img src="assets/hardware/real-c.jpg" alt="Assembly View C" width="31%">
</p>

## Firmware

### Config and build

<p align="center">
  <img src="assets/firmware/config.gif" alt="PCB Front" width="48%">
  <img src="assets/firmware/build.gif" alt="PCB Back" width="48%">
</p>

### Runtime

![Runtime](assets/firmware/run-time.gif)

## Contributing

- Read [AGENTS.md](AGENTS.md) before making changes.
- For structural work, also read `docs/ARCHITECTURE.md`, `docs/MQTT_PROTOCOL.md`, and `docs/API_REFERENCE.md`.
- Keep changes narrow, update matching docs when contracts change, and run the narrowest verification for the area you touched.

## License

MIT. See [LICENSE.md](LICENSE.md).
