# CONSTRAINTS.md — Hard Constraints

> These are non-negotiable. No task, no matter how urgent, overrides them.
> If a constraint needs to change, update this file explicitly with rationale.
> Agent: check this file before proposing any solution.

---

## Security Constraints

### SEC-01 — No hardcoded credentials

MQTT credentials, WiFi passwords, and API keys must come from Kconfig (build-time)
or NVS (runtime). Never in source code, never in version control.

### SEC-02 — OTA over HTTPS only

OTA firmware updates must use HTTPS with an embedded CA certificate
(`_binary_*_pem_start`). Plain HTTP OTA is forbidden.

### SEC-03 — OTA rollback required

Every OTA implementation must include a rollback path and a validation task
that confirms the new firmware is functional before committing the update.

---

## Hardware Constraints

### HW-01 — I2C bus speed: 400 kHz

The shared I2C bus must run at 400 kHz. Both SHT3x (0x44) and DS3231 (0x68)
support fast mode. Do not drop to 100 kHz — and do not exceed 400 kHz.

### HW-02 — XPT2046 SPI speed: 2 MHz max

XPT2046 touch controller cannot exceed 2 MHz on SPI. ST7789 runs at 10 MHz.
These are on the same SPI2_HOST bus — XPT2046 must use a separate, slower
`spi_device_handle_t`. Never raise XPT2046 speed to match ST7789.

### HW-03 — SPI host: SPI2_HOST only

Display and touch are both on SPI2_HOST. Do not reassign to SPI3_HOST
without an explicit hardware decision + ADR.

### HW-04 — I2C device addresses are fixed

SHT3x = 0x44 (ADDR pin tied low). DS3231 = 0x68. These are hardware-defined.
Do not use configurable address without a matching hardware change.

---

## Firmware API Constraints

### FW-01 — Use ESP-IDF v5.x i2c_master API only

Never use the legacy `i2c_master_cmd_begin` / `i2c_cmd_link_create` API.
Use only the v5.x `i2c_master` new API (`i2c_master_dev_handle_t`, etc.).

### FW-02 — Entry point is void app_main(void)

The firmware entry point is `void app_main(void)` — not `int main()`.
Do not change the signature or add a return value.

### FW-03 — WiFi "connected" = IP_EVENT_STA_GOT_IP

Never treat `WIFI_EVENT_STA_CONNECTED` as "connected". The system is only
connected when `IP_EVENT_STA_GOT_IP` fires. All downstream services
(MQTT connect, HTTP server init) must wait for this event.

### FW-04 — MQTT: copy event data before returning from callback

MQTT event data pointers are only valid inside the event callback. Always
copy any data you need before returning. Never store raw pointers.

### FW-05 — MQTT: subscribe in CONNECTED callback only

MQTT subscriptions must be done inside the `MQTT_EVENT_CONNECTED` handler,
not at init time and not in a separate task. This ensures re-subscription
after reconnects.

### FW-06 — No TODO comments left in merged code

TODO comments are planning tools only. Remove before marking a task complete.
If a follow-up is needed, add it as a `[ ]` item in `TODO.md` instead.

---

## Code Style Constraints

### CS-01 — 4-space indent, spaces only

All firmware C code: 4 spaces per indent level. No tabs. Column limit: 120.
Enforced by `.clang-format` at project root (Google base, Allman for functions).

### CS-02 — SortIncludes: Never

ESP-IDF include order is intentional (system → esp → FreeRTOS → local).
clang-format must not reorder includes. `SortIncludes: Never` in `.clang-format`.

### CS-03 — Flutter: adaptive colors via context.colors only

In Flutter build methods: always `final c = context.colors;` first.
Never reference `AppColors.bg`, `AppColors.surface`, `AppColors.border`,
`AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.surfaceVar` directly —
these are theme-adaptive and must go through the extension.
`AppColors` static const (non-adaptive: `primary`, `online`, `offline`, `warning`) are fine to use directly.

---

## Process Constraints

### PR-01 — No task marked complete without verification

A task is complete only after running tests, checking logs, or demonstrating
correct behaviour. Marking `[x]` before verification is forbidden.

### PR-02 — No guessing when stuck

If a root cause is not confirmed: stop, write a hypothesis in `tasks/debug.md`,
run a targeted experiment, confirm root cause, then fix. Random fixes are forbidden.

### PR-03 — Minimal scope per change

Each change touches only what the current task requires. Refactoring unrelated
code in the same commit is forbidden unless it is the explicit task.

### PR-04 — Architectural decisions require an ADR

Any change that affects component boundaries, protocol choices, pin assignments,
or bus topology must be proposed as an ADR in `docs/DECISIONS.md` and approved
before implementation.

---

## See also

- [[DECISIONS]] — ADRs that explain why some constraints exist
