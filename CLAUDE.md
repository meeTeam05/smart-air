# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**smart-air** — ESP32-S3 indoor air quality monitor + smart home controller.
Stack: ESP32-S3 (ESP-IDF v5.x) · Flutter (iOS/Android) · self-hosted IoT cloud (EMQX + Fastify + PostgreSQL/TimescaleDB + Redis).

Full system design: `docs/ARCHITECTURE.md`. Hard constraints: `docs/CONSTRAINTS.md`. Decisions: `docs/DECISIONS.md`.

---

## Firmware (`firmware/`)

```bash
cd firmware
idf.py build                          # compile
idf.py flash                          # flash to device
idf.py monitor                        # serial monitor
idf.py flash monitor                  # flash + open monitor
idf.py -p /dev/ttyUSB0 flash monitor  # specify port
idf.py menuconfig                     # Kconfig editor
idf.py fullclean                      # wipe build directory
idf.py size                           # binary size report
```

Entry: `firmware/main/main.c` → `app_main()` → `sysload_init()`.
Components: `firmware/components/` — `ble_prov`, `wifi`, `mqtt`, `led`, `buzzer`, `dns`, `i2c_bus`, `sht3x`, `ds3231`, `spi_bus`, `st7789`, `xpt2046`, `ota`, `config`, `core`.

---

## App (`app/`)

```bash
cd app
flutter pub get                      # install dependencies
flutter run                          # run on device/emulator
flutter test                         # all tests
flutter test test/widget_test.dart   # single test file
flutter analyze                      # lint (flutter_lints)
flutter build apk --release          # Android APK
flutter build ios --release          # iOS
dart fix --apply                     # apply automated lint fixes
```

Key packages: `flutter_blue_plus` (BLE provisioning), `permission_handler`, `wifi_scan`.

---

## Knowledge & Memory

| Tier      | Location                             | Purpose                                          |
| --------- | ------------------------------------ | ------------------------------------------------ |
| Session   | `TODO.md`                            | Active tasks and in-progress notes               |
| Long-term | `.claude/knowledge/wiki/` (Obsidian) | Stable, reusable — start from `_master-index.md` |

**No `memory.md`** — Obsidian wiki is the persistent memory for this project.

---

## Session Start

Read in this order before any work:

1. `TODO.md` — current task state
2. `docs/CONSTRAINTS.md` — hard limits
3. `.claude/knowledge/wiki/_master-index.md` — long-term knowledge index

Or run `/daily`.

---

## Agents & Skills

- **Agents:** `.claude/agents/` — invoke as subagents, one task per agent, load on demand
- **Skills:** `.claude/skills/` — load the matching skill BEFORE writing code in that domain, never load all at once

Full reference tables in `.claude/rules/workflow.md`.

---

@.claude/rules/workflow.md
@.claude/rules/firmware.md
@.claude/rules/app.md
@.claude/rules/process.md

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **smart-air** (1462 symbols, 2009 relationships, 35 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

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
