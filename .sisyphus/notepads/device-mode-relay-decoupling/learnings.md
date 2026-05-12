# Learnings

## 2026-05-12 Baseline Audit Findings
- **Coupling points identified**:  is tightly coupled with  module via  (in ) and  (in shadow publishing).
- **Initialization ordering**:  manages the bootstrap sequence. Currently, , , and  are all gated by .
- **Command Handlers**: Both  and  handlers are gated by . Decoupling will require splitting these guards or abstracting the relay side-effects.
- **Verification method**:  is currently  by default in , but likely  in active  if testing with relays. Build verification should focus on ensuring  compiles even when  are disabled.

## 2026-05-12 Baseline Audit Findings
- **Coupling points identified**: `device_mode` is tightly coupled with `relay` module via `relay_force_all_off` (in `device_mode_set`) and `relay_get_all` (in shadow publishing).
- **Initialization ordering**: `sysload_init` manages the bootstrap sequence. Currently, `buzzer_init`, `relay_init`, and `device_mode_init` are all gated by `#if CONFIG_SA_ENABLE_RELAYS`.
- **Command Handlers**: Both `relay_set` and `device_mode` handlers are gated by `CONFIG_SA_ENABLE_RELAYS`. Decoupling will require splitting these guards or abstracting the relay side-effects.
- **Verification method**: `CONFIG_SA_ENABLE_RELAYS` is currently `n` by default in `Kconfig.projbuild`, but likely `y` in active `sdkconfig` if testing with relays. Build verification should focus on ensuring `device_mode` compiles even when `RELAYS` are disabled.

## 2026-05-12 10:30:00 - Sysload Bootstrap Decoupling
- Successfully decoupled `device_mode` registration from `CONFIG_SA_ENABLE_RELAYS` in `sysload.c`.
- `buzzer_init()` and `device_mode_init()` are now ungated, as they are required for basic device state management even if relays are disabled.
- `handle_relay_set` and its MQTT registration remain gated by `CONFIG_SA_ENABLE_RELAYS`.
- Registration order preserved: commands are registered before `mqtt_start()`.

## 2026-05-12 Task 4 Evidence Wave
- Static guard proof confirms `handle_device_mode`, `device_mode_init`, and `mqtt_register_command_handler("device_mode", ...)` are outside relay compile guards in `sysload.c`.
- Relay-only path remains compile-gated: `handle_relay_set`, `relay_init`, and `mqtt_register_command_handler("relay_set", ...)` stay under `#if CONFIG_SA_ENABLE_RELAYS`.
- `device_mode.c` relay side effects remain compile-gated: `relay_get_all` and `relay_force_all_off` are both wrapped by `#if CONFIG_SA_ENABLE_RELAYS`.
- Command-path static check still returns `ESP_ERR_INVALID_ARG` for missing payload, invalid JSON, missing/non-string mode, and unsupported mode values.

## 2026-05-12 F2 Firmware Code Quality Review
- Scope reviewed only: `firmware/components/core/sysload/sysload.c` and `firmware/components/core/device_mode/device_mode.c`.
- Guard boundary/order confirmed: `handle_device_mode` ungated; `device_mode_init` ungated; `mqtt_register_command_handler("device_mode", ...)` present before `mqtt_start(...)`; relay handler/init/registration remain under `#if CONFIG_SA_ENABLE_RELAYS`.
- Relay side effects in `device_mode.c` remain guarded: `relay_get_all` and `relay_force_all_off` both compile-gated by `CONFIG_SA_ENABLE_RELAYS`.
- Duplication check: exactly one `device_mode` registration and one `relay_set` registration in `sysload.c`; no duplicate relay side-effect calls in `device_mode.c`.
- Verification limits: build evidence reused from Task 4 shows `idf.py` missing (`command not found`), so no fresh build claim was made in this environment.
- LSP diagnostics show only known ESP-IDF toolchain/clang flag incompatibilities (`-mlongcalls`, `-fno-shrink-wrap`, `-fstrict-volatile-bitfields`, `-fno-tree-switch-conversion`) and no new source-level regression signal.

## 2026-05-12 F3 QA Evidence Verdict
- Deterministic gate rule validated: when `idf.py` is unavailable, blocker is acceptable only if explicitly captured in evidence and backed by concrete static guard checks; this wave satisfies that rule via task-4 blocker files plus verified guard/order locations in `sysload.c` and `device_mode.c`.
