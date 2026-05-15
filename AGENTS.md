# AGENTS.md

Working instructions for the `smart-air` repository.

## Project Summary

`smart-air` is an ESP32-S3 indoor air quality monitor and smart home controller with four tightly-coupled domains:

- `firmware/`: ESP-IDF v5.x firmware running on ESP32-S3.
- `app/`: Flutter mobile app for iOS and Android.
- `server/`: self-hosted cloud stack, Docker Compose wiring, EMQX, Redis, PostgreSQL/TimescaleDB, Grafana, and related operations.
- `server/api/`: Fastify API that bridges the mobile app, MQTT broker, persistence, and device state.
- `docs/`: architecture, API, MQTT contract, hardware references, and audits.
- `scripts/`: smoke tests and operator utilities.

This repository behaves like one IoT system, not four isolated apps. Many feature changes cross multiple layers.

## Read This First

Before making structural or behavior changes, read the most relevant source-of-truth docs:

- `docs/ARCHITECTURE.md`: system layers, boot flow, firmware component map, buses, cloud topology.
- `docs/MQTT_PROTOCOL.md`: source of truth for device topics, telemetry payloads, command topics, and OTA messaging.
- `docs/API_REFERENCE.md`: HTTP routes, auth expectations, and device ID conventions.
- `app/test/goldens/README.md`: golden-test workflow and constraints for Flutter UI verification.
- `server/docker-compose.yml`: service topology and infra wiring.

## Local Toolchain Rules

- Use `rtk` for shell commands by default. If a command needs exact shell syntax, redirection, or env bootstrap, use `rtk proxy <cmd>` instead of dropping the wrapper.
- Use GitNexus CLI from the repo root via `rtk proxy npx gitnexus ...`. Use `status` before trusting graph output, `analyze` when the index is stale, `impact` before editing symbols, and `detect_changes` before commit.
- For firmware, activate ESP-IDF in the same shell invocation before any `idf.py` call. Source the active local `export.sh` for that machine, then run `idf.py` in the same command chain. Do not run `idf.py` bare in a fresh shell.
- For Flutter, work from `app/`. Use `rtk proxy flutter doctor -v` for local toolchain checks, and run `flutter pub get` after dependency changes before `flutter analyze` / `flutter test`.

## Where To Work

Use this map before editing:

| Goal                                                    | Primary place to start                                      | Also inspect                                                                 |
| ------------------------------------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Firmware boot, provisioning, Wi-Fi, MQTT startup        | `firmware/main/main.c`, `firmware/components/core/sysload/` | `docs/ARCHITECTURE.md`                                                       |
| Sensor, display, bus, relay, OTA, hardware-facing logic | `firmware/components/`                                      | `firmware/sdkconfig`, `docs/ARCHITECTURE.md`, hardware references in `docs/` |
| Mobile auth, routing, app state                         | `app/lib/providers/`, `app/lib/core/router.dart`            | `app/lib/services/`, `app/lib/models/`                                       |
| Mobile UI changes                                       | `app/lib/screens/`, `app/lib/widgets/`, `app/lib/design/`   | `app/test/`, golden docs                                                     |
| API routes and HTTP contracts                           | `server/api/src/routes/`                                    | `docs/API_REFERENCE.md`, relevant tests                                      |
| MQTT ingestion, shadow, telemetry, EMQX bridging        | `server/api/src/services/`                                  | `docs/MQTT_PROTOCOL.md`, `server/api/src/plugins/`                           |
| Infra, broker, DB, local stack wiring                   | `server/`                                                   | `server/docker-compose.yml`, `server/db/migrations/`                         |

When a task changes telemetry, commands, device shadow, auth, or provisioning, assume at least two layers are involved and inspect both sides of the boundary before editing.

## Cross-Stack Rules

- Treat `docs/MQTT_PROTOCOL.md` as the canonical contract for MQTT topics and payloads.
- Treat `docs/API_REFERENCE.md` as the canonical contract for public HTTP behavior unless the task explicitly changes it.
- Device IDs must remain lowercase MAC-style identifiers; preserve normalization behavior used by the API.
- Do not change telemetry fields, command payloads, topic names, auth semantics, or shadow shapes without updating the matching docs and impacted codepaths together.
- Prefer narrow, layer-appropriate changes. Do not mix firmware, app, API, and infra refactors unless the task truly requires it.

## Firmware Rules

When touching `firmware/`:

- Entry point remains `void app_main(void)`.
- Use ESP-IDF v5.4.2 APIs.
- Use only the new I2C master API (`i2c_master_dev_handle_t`, `i2c_master_bus_handle_t`, `i2c_master_transmit`, `i2c_master_receive`). Do not use legacy I2C APIs.
- Wi-Fi-dependent MQTT or HTTP startup must wait until `IP_EVENT_STA_GOT_IP`.
- MQTT callback payloads must be copied before returning from the callback.
- MQTT subscriptions belong in `MQTT_EVENT_CONNECTED` so reconnects re-subscribe correctly.
- OTA must use HTTPS and include rollback/validation behavior.
- Use `ESP_ERROR_CHECK` or explicit `esp_err_t` handling for fallible ESP-IDF operations.
- Follow the existing `.clang-format`; `SortIncludes: Never` is intentional.
- Respect hardware constraints already encoded in config and drivers:
  - I2C is 400 kHz.
  - SHT3x address is `0x44`.
  - DS3231 address is `0x68`.
  - Display uses `ILI9225` on `SPI2_HOST`.
  - `SD Card` uses `SPI3_HOST`; do not merge it onto the display SPI host.
  - Gas sensors use `ADC1`; keep `CO` and `NO2` on separate ADC-capable pins.
- Do not change bus topology, pin assignments, or protocol choices casually; check docs and impacted modules first.

## App Rules

When touching `app/`:

- Follow the existing Riverpod + `AsyncNotifierProvider` architecture instead of inventing new state patterns.
- In widget `build()` methods, use `final c = context.colors;` and consume adaptive colors through `context.colors`.
- Do not use raw adaptive color literals directly in widgets when the design tokens already provide them.
- Non-adaptive semantic colors may stay direct only when the existing design system already does that.
- Do not hand-edit generated files such as `.freezed.dart` or `.g.dart`.
- Keep JWT access tokens in memory; refresh tokens belong in secure storage.
- Preserve the current auth/session-restore flow unless the task explicitly changes auth behavior.
- Reuse the existing design system under `app/lib/design/` and existing widgets before creating new UI primitives.
- Keep operational UI dense, stable, and readable on narrow devices.
- Keep widget and golden tests deterministic.

## Server and API Rules

When touching `server/` or `server/api/`:

- Keep Fastify plugin, route, and service boundaries intact; do not add ad-hoc global state.
- Validate request bodies, params, telemetry payloads, command payloads, and shadow updates at system boundaries.
- Preserve explicit auth, access control, device ownership, and command authorization checks.
- Accept JWTs only via `Authorization: Bearer <token>`.
- Secrets must come from environment or deployment config, never checked-in source.
- Device-to-broker MQTT must remain TLS-backed in production-oriented configuration.
- Database schema changes require a new migration in `server/db/migrations/`; do not rewrite applied migrations unless explicitly requested.
- Keep Docker Compose, EMQX, and service wiring changes scoped to the service actually being modified.
- Preserve startup guards, body-limit parsing, and logger redaction patterns already present in the API.

## Generated, Vendor, and Runtime Noise

Avoid treating these as normal editing/search targets unless the task explicitly requires them:

- `firmware/managed_components/`
- `firmware/build/`
- `app/build/`
- `app/.dart_tool/`
- `server/grafana/data/`
- `server/postgres/data/`
- `server/portainer/data/`
- `server/pgadmin/data/`
- `tmp/`

Also treat `app/android/` and `app/ios/` as mostly platform boilerplate; default app work belongs in `app/lib/` and `app/test/`.

Large files that are still human-maintained include `firmware/sdkconfig`, `server/db/migrations/`, KiCad files under `hardware/`, and architecture/protocol assets under `docs/`.

## Verification Commands

Choose the narrowest checks that match the changed area.

### Firmware

Run from `firmware/`:

```bash
get_idf
idf.py build
idf.py flash
idf.py monitor
idf.py flash monitor
idf.py menuconfig
idf.py size
```

### App

Run from `app/`:

```bash
flutter pub get
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

Set `RUN_GOLDENS=true` when intentionally running golden coverage.

### Server / API

Run from `server/` or `server/api/` as appropriate:

```bash
docker compose config
docker compose ps
docker compose logs
npm test
npm run migrate
npm run dev
```

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **smart-air** (13373 symbols, 31144 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/smart-air/context` | Codebase overview, check index freshness |
| `gitnexus://repo/smart-air/clusters` | All functional areas |
| `gitnexus://repo/smart-air/processes` | All execution flows |
| `gitnexus://repo/smart-air/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
