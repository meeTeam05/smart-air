---
name: smart-air-verification
description: Use after changes in smart-air to select and run the narrowest firmware, Flutter, server, or docs verification checks.
---

# Smart Air Verification

Pick the smallest checks that prove the change.

## Firmware

Use for C, CMake, Kconfig, drivers, component wiring, sensor, MQTT, OTA, relay,
display, provisioning, or boot-flow changes:

```bash
cd firmware
idf.py build
```

Use flash/monitor when hardware behavior changed:

```bash
idf.py flash monitor
idf.py -p /dev/ttyACM0 flash monitor
```

## Flutter App

Use for Dart, widget, provider, route, service, model, theme, and generated model
changes:

```bash
cd app
flutter analyze
flutter test
```

Run code generation after model source changes:

```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

## Server API

Use for Fastify route, service, plugin, job, auth, command, shadow, telemetry,
and migration changes:

```bash
cd server/api
npm test
```

Run migrations when schema behavior changes:

```bash
cd server/api
npm run migrate
```

## Infrastructure

Use after Docker Compose or broker/service wiring edits:

```bash
cd server
docker compose config
docker compose ps
```

## Reporting

Report:

- commands run
- pass/fail result
- any blocked command and exact reason
- remaining unverified risk
