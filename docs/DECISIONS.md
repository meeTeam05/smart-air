# DECISIONS.md — Architecture Decision Records (ADR)

> Log of significant decisions made during the project.
> Each entry answers: What was decided, why, and what was rejected.
> Agent: propose new ADRs here; user approves before implementation.

---

## Format

```
## ADR-XXX — Title

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Superseded by ADR-XXX

### Context
Why this decision was needed.

### Decision
What was decided.

### Alternatives Rejected
What else was considered and why it was rejected.

### Consequences
What this decision implies going forward.
```

---

<!-- Agent: Add new ADR below this line -->

---

## ADR-001 — ESP-IDF v5.x new i2c_master API

**Date:** 2026-03-18
**Status:** Accepted

### Context

ESP-IDF v5.x introduced a new `i2c_master` API that replaces the legacy
`i2c_master_cmd_begin` / `i2c_cmd_link_create` / `i2c_cmd_link_delete` pattern.
Both APIs exist in v5.x, but the legacy API is deprecated.

### Decision

Use only the new `i2c_master` API (`i2c_new_master_bus`, `i2c_master_dev_handle_t`,
`i2c_master_transmit`, `i2c_master_receive`). The legacy API is forbidden (see CONSTRAINTS.md FW-01).

### Alternatives Rejected

- **Legacy i2c API**: Deprecated in v5.x, will be removed in a future version. No reason to build on it.

### Consequences

- All I2C driver code in `firmware/components/drivers/i2c_*` must use the new API.
- Each I2C device gets its own `i2c_master_dev_handle_t`; bus handle is shared.

---

## ADR-002 — Shared SPI2_HOST for display and touch

**Date:** 2026-03-18
**Status:** Accepted

### Context

ST7789 (display) and XPT2046 (touch) are both SPI devices. They can share a bus
or use separate buses. The hardware PCB routes both to SPI2_HOST.

### Decision

Share SPI2_HOST between ST7789 and XPT2046. Each device gets its own
`spi_device_handle_t` with its own speed setting: 10 MHz for ST7789, 2 MHz for XPT2046.

### Alternatives Rejected

- **Separate SPI buses (SPI2 + SPI3)**: Would use more GPIO pins and MCU resources. No performance benefit — both devices are never accessed simultaneously.
- **Bit-banging XPT2046**: Unnecessary complexity given the speed constraint is already met with a slow SPI handle.

### Consequences

- XPT2046 must always use the slow device handle. Passing the wrong handle is a bug.
- Bus access is serialized by ESP-IDF's SPI bus lock — no additional mutex needed for multi-task SPI access.

---

## ADR-003 — WiFi: event-driven station mode, no polling

**Date:** 2026-03-18
**Status:** Accepted

### Context

WiFi connection state can be tracked by polling or by reacting to events from the
ESP-IDF WiFi/IP event system.

### Decision

Use the ESP-IDF event loop exclusively. WiFi init registers handlers for
`WIFI_EVENT` and `IP_EVENT`. "Connected" is defined as `IP_EVENT_STA_GOT_IP`
(not `WIFI_EVENT_STA_CONNECTED`). An `EventGroup` bit signals downstream
services (MQTT, HTTP) when the IP is available.

### Alternatives Rejected

- **Polling `esp_wifi_sta_get_ap_info`**: Wastes CPU, misses reconnect events, introduces latency.
- **Using WIFI_EVENT_STA_CONNECTED as "connected"**: This event fires before an IP is assigned — MQTT/HTTP will fail if started at this point.

### Consequences

- All services that require network must wait on the `EventGroup` IP bit before starting.
- Reconnect logic must re-register MQTT subscriptions on each new `IP_EVENT_STA_GOT_IP`.

---

## ADR-004 — clang-format: Google base with ESP-IDF overrides

**Date:** 2026-03-18
**Status:** Accepted

### Context

The project inherited a Linux Kernel `.clang-format` (764 lines, tabs, indent-8,
80-column, ~650 Linux-specific ForEachMacros). ESP-IDF source uses 4-space indent,
spaces only, and intentional include ordering — the opposite of Linux Kernel style.

### Decision

Replace entirely with a Google-base config tuned for ESP-IDF:

- 4-space indent, spaces only
- 120-column limit
- Allman brace wrapping for functions, K&R for control flow
- `SortIncludes: Never` (preserves ESP-IDF include order)
- Right-aligned pointer: `uint8_t *ptr`
- 7 FreeRTOS macros replacing ~650 Linux Kernel ForEachMacros

### Alternatives Rejected

- **LLVM base**: Similar to Google but less consistent with Espressif examples observed in the wild.
- **Linux Kernel style**: Tabs and indent-8 conflict with every ESP-IDF example and Espressif's own source code.
- **No clang-format**: Inconsistent formatting across contributors; harder to review diffs.

### Consequences

- Existing source files (written with the old config) are not auto-reformatted — that should be a separate, deliberate team commit.
- clang-format v22 required (`SortIncludes: Never` enum form; trailing `...` YAML marker causes parse error in v22).

---

## See also

- [[review]] — Task reviews that triggered new ADRs
