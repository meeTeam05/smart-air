# Issues

## 2026-05-12 Baseline Issues
- **Tight Coupling**: `device_mode.c` directly calls `relay.h` APIs. If `CONFIG_SA_ENABLE_RELAYS` is disabled, the linker will fail if these calls are not properly guarded within `device_mode.c`.
- **Initialization Gating**: `device_mode_init` is currently unreachable if `CONFIG_SA_ENABLE_RELAYS` is `n` because it resides within the `#if CONFIG_SA_ENABLE_RELAYS` block in `sysload.c`. This prevents telemetry gating even if sensors are active.

## 2026-05-12 Task 4 Issues
- Build matrix blocked by environment: `idf.py` is not available in PATH (`command not found: idf.py`). Evidence recorded in task-4-default-build.txt and task-4-relay-disabled-build.txt.
- LSP diagnostics on `sysload.c` and `device_mode.c` show expected ESP-IDF toolchain flag incompatibility with clang (`-mlongcalls`, `-fno-shrink-wrap`, `-fstrict-volatile-bitfields`, `-fno-tree-switch-conversion`) and no new source-level regression signal.
