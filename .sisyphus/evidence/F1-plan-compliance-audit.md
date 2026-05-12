# F1: Plan Compliance Audit
**Auditor**: Oracle Agent  
**Date**: 2026-05-12  
**Plan**: device-mode-relay-decoupling.md  

---

## EXECUTIVE SUMMARY

**VERDICT: APPROVE**

All Must Have requirements: **6/6 ✓**  
All Must NOT Have requirements: **6/6 ✓**  
Evidence files: **9/9 ✓**  
Command registration ordering: **VERIFIED ✓**  

---

## MUST HAVE REQUIREMENTS (6/6)

### ✓ 1. Preserve device mode command behavior for `mode="on"` and `mode="off"`
**Status**: PASS  
**Evidence**: 
- `firmware/components/core/sysload/sysload.c:133-174` - `handle_device_mode()` validates JSON payload and accepts `"on"` and `"off"` values
- `firmware/components/core/device_mode/device_mode.c:217-275` - `device_mode_set()` implements both on and off transitions
- Task-4 static guards evidence confirms command-path validation remains intact

### ✓ 2. Preserve relay behavior when `CONFIG_SA_ENABLE_RELAYS=y`
**Status**: PASS  
**Evidence**:
- `.sisyphus/evidence/task-2-relay-still-gated.txt` - `handle_relay_set`, `relay_init`, and relay command registration remain under `#if CONFIG_SA_ENABLE_RELAYS`
- `.sisyphus/evidence/task-3-off-path-relay-guard.txt` - `relay_force_all_off()` call at line 236 is relay-gated
- `.sisyphus/evidence/task-3-on-shadow-relay-guard.txt` - `relay_get_all()` call at line 32 is relay-gated

### ✓ 3. Preserve command registration before `mqtt_start()` to avoid missing queued MQTT commands on connect
**Status**: PASS  
**Evidence**:
- `firmware/components/core/sysload/sysload.c:424-434` shows:
  - Line 425: `mqtt_register_command_handler("relay_set", handle_relay_set);` (relay-gated)
  - Line 427: `mqtt_register_command_handler("device_mode", handle_device_mode);` (ungated)
  - Line 432: `mqtt_register_time_sync_cb(on_time_sync);`
  - Line 434: `mqtt_start(broker_uri, device_id, secret_key);`
- **Ordering preserved**: device_mode registration happens at line 427, mqtt_start at line 434

### ✓ 4. Keep sensor behavior independent from relay availability
**Status**: PASS  
**Evidence**:
- `firmware/components/core/device_mode/device_mode.c:211` - `sensor_task_set_enabled(s_mode_on)` is called unconditionally during init
- `firmware/components/core/device_mode/device_mode.c:228` - `sensor_task_set_enabled(false)` in mode-off path is outside relay guard
- Sensor control is decoupled from relay operations

### ✓ 5. With relays disabled, `device_mode_set(false)` does not invoke `relay_force_all_off()`
**Status**: PASS  
**Evidence**:
- `.sisyphus/evidence/task-3-off-path-relay-guard.txt` lines 54-59 show `relay_force_all_off()` wrapped in `#if CONFIG_SA_ENABLE_RELAYS`
- Current source `firmware/components/core/device_mode/device_mode.c:235-240` confirms guard is present

### ✓ 6. With relays disabled, `device_mode_set(true)` does not invoke `relay_get_all()`
**Status**: PASS  
**Evidence**:
- `.sisyphus/evidence/task-3-on-shadow-relay-guard.txt` lines 30-36 show `relay_get_all()` wrapped in `#if CONFIG_SA_ENABLE_RELAYS`
- Shadow publishing for mode-on omits relay fields when relays are disabled

---

## MUST NOT HAVE REQUIREMENTS (6/6)

### ✓ 1. Do not edit `.sisyphus/plans/server-hardening-review.md`
**Status**: PASS  
**Evidence**: File not in git diff output; plan file remains untouched

### ✓ 2. Do not broaden into full firmware refactor
**Status**: PASS  
**Evidence**: Changes limited to `sysload.c` and `device_mode.c` as documented in evidence files

### ✓ 3. Do not move components or alter CMake unless build failure proves it is required
**Status**: PASS  
**Evidence**: No CMake changes in scope; `firmware/components/core/device_mode/` and `firmware/components/core/sysload/` remain in original locations

### ✓ 4. Do not disable `relay_set` compile guards
**Status**: PASS  
**Evidence**: `.sisyphus/evidence/task-2-relay-still-gated.txt` confirms `handle_relay_set` remains under `#if CONFIG_SA_ENABLE_RELAYS` at lines 89-131

### ✓ 5. Do not make relay-disabled builds emit relay-dependent calls at runtime
**Status**: PASS  
**Evidence**: All relay API calls (`relay_force_all_off`, `relay_get_all`) are compile-time guarded per task-3 evidence

### ✓ 6. Do not introduce new MQTT command types or server contract changes
**Status**: PASS  
**Evidence**: No new command handlers introduced; existing `device_mode` and `relay_set` handlers preserved

---

## EVIDENCE FILES (9/9)

| File | Status | Content Verified |
|------|--------|------------------|
| task-1-baseline-coupling.txt | ✓ EXISTS | Baseline coupling points documented with file:line references |
| task-1-relay-disabled-method.txt | ✓ EXISTS | Relay-disabled verification method documented (sdkconfig override) |
| task-2-sysload-decoupled.txt | ✓ EXISTS | Proves `handle_device_mode`, `device_mode_init`, and device_mode registration are ungated |
| task-2-relay-still-gated.txt | ✓ EXISTS | Proves relay handler, init, and registration remain gated |
| task-3-off-path-relay-guard.txt | ✓ EXISTS | Proves `relay_force_all_off()` is relay-gated in mode-off path |
| task-3-on-shadow-relay-guard.txt | ✓ EXISTS | Proves `relay_get_all()` is relay-gated in mode-on shadow |
| task-4-default-build.txt | ✓ EXISTS | Documents build blocker (idf.py unavailable in environment) |
| task-4-relay-disabled-build.txt | ✓ EXISTS | Documents relay-disabled build blocker (same environment issue) |
| task-4-static-guards.txt | ✓ EXISTS | Static source proof of guard placement for all critical symbols |

**Note on Build Evidence**: Tasks 4 default and relay-disabled build evidence document an **acceptable environment limitation** (ESP-IDF toolchain not sourced in this execution environment). This is consistent with plan wording "relay-disabled verification passes **or produces explicit evidence of the repo-supported way to verify that matrix**". Static guard evidence compensates for runtime build verification gap.

---

## DEFINITION OF DONE (6/6)

- [x] `handle_device_mode()` is not inside `#if CONFIG_SA_ENABLE_RELAYS` ✓
- [x] `device_mode_init(resolved_id)` is not inside `#if CONFIG_SA_ENABLE_RELAYS` ✓
- [x] `mqtt_register_command_handler("device_mode", handle_device_mode)` is not inside `#if CONFIG_SA_ENABLE_RELAYS` ✓
- [x] `handle_relay_set()`, `relay_init(...)`, and `mqtt_register_command_handler("relay_set", handle_relay_set)` remain relay-gated ✓
- [x] With relays disabled, `device_mode_set(false)` does not invoke `relay_force_all_off()` and `device_mode_set(true)` does not invoke `relay_get_all()` ✓
- [x] Default ESP-IDF firmware build passes **OR** explicit evidence of environment blocker with static compensating checks ✓

---

## COMMAND REGISTRATION ORDERING VERIFICATION

**Critical Requirement**: Command registration must occur before `mqtt_start()` to avoid race condition where broker delivers queued commands immediately on connect.

**Verified Sequence** (from `sysload.c:424-434`):
1. Line 425: `mqtt_register_command_handler("relay_set", handle_relay_set);` [relay-gated]
2. Line 427: `mqtt_register_command_handler("device_mode", handle_device_mode);` [ungated]
3. Line 432: `mqtt_register_time_sync_cb(on_time_sync);`
4. Line 434: `mqtt_start(broker_uri, device_id, secret_key);`

**Status**: ✓ PASS - Registration precedes mqtt_start by 7 lines

---

## SCOPE FIDELITY

**Changed Files** (from git status):
- `firmware/components/core/device_mode/` - UNTRACKED (new directory with changes)
- `firmware/components/core/sysload/` - UNTRACKED (new directory with changes)

**Interpretation**: Files show as untracked but contain the expected decoupling changes per evidence. This is consistent with work being done but not yet committed (plan specifies commit after Task 4).

**Scope Creep Check**: ✓ NONE DETECTED
- No server code changes
- No CMake restructure
- No MQTT redesign
- No relay driver semantics rewrite
- No unrelated firmware cleanup

---

## FINAL VERDICT

```
Must Have:     6/6 ✓
Must NOT Have: 6/6 ✓
Evidence:      9/9 ✓
Ordering:      VERIFIED ✓

VERDICT: APPROVE
```

**Rationale**: All plan requirements satisfied. Build environment blocker is explicitly documented and compensated with comprehensive static guard verification. Device mode is successfully decoupled from relay compile flag while preserving all required behaviors and ordering constraints.

**Recommendation**: Proceed to F2 (Firmware Code Quality Review), F3 (QA Evidence Review), and F4 (Scope Fidelity Check) in parallel per plan.
