# Device Mode / Relay Decoupling Plan

## TL;DR

> **Quick Summary**: Fix the firmware design bug where device mode support is incorrectly compiled behind `CONFIG_SA_ENABLE_RELAYS`. Device mode must exist independently; relay behavior is only an optional side effect of mode transitions.
>
> **Deliverables**:
> - Ungated `device_mode` command handler and registration in `sysload.c`.
> - Ungated `device_mode_init(resolved_id)` before `mqtt_start()`.
> - Relay-only behavior remains guarded by `CONFIG_SA_ENABLE_RELAYS`.
> - `device_mode.c` no longer invokes relay-dependent APIs when relays are disabled.
>
> **Estimated Effort**: Short
> **Parallel Execution**: YES - 2 small implementation tasks can run after baseline audit
> **Critical Path**: Task 1 → Tasks 2/3 → Task 4 → Final Verification

---

## Context

### Original Request
User asked to create a new plan only for this issue:

> `device_mode` là mode cấp thiết bị, không phải feature phụ thuộc relay. Relay chỉ là một side effect khi mode chuyển off... `handle_device_mode`, `mqtt_register_command_handler("device_mode", handle_device_mode)`, `device_mode_init(...)` không nên bị bọc bởi `#if CONFIG_SA_ENABLE_RELAYS`.

### Current Evidence
- `firmware/components/core/sysload/sysload.c` currently places both `handle_relay_set()` and `handle_device_mode()` under `#if CONFIG_SA_ENABLE_RELAYS`.
- `sysload_init()` currently places `buzzer_init()`, `relay_init()`, `device_mode_init()`, `mqtt_register_command_handler("relay_set", ...)`, and `mqtt_register_command_handler("device_mode", ...)` inside one relay-gated runtime-control bootstrap block.
- `firmware/components/core/device_mode/device_mode.c` currently calls relay APIs directly:
  - `relay_force_all_off()` in the `mode off` path.
  - `relay_get_all()` in `publish_mode_on_shadow()`.
- GitNexus impact checks for `sysload_init` and `device_mode_set` returned **LOW risk**, with no upstream callers/processes affected.

### Metis Review Findings Incorporated
- Ungating only `sysload.c` is insufficient; `device_mode.c` also has relay coupling.
- Keep the fix narrow: firmware only, mainly `sysload.c` and `device_mode.c`.
- Do not redesign MQTT architecture, CMake, server hardening, relay driver, or broader firmware structure.
- Preserve ordering: `device_mode_init()` and command registration must happen before `mqtt_start()`.

---

## Work Objectives

### Core Objective
Make `device_mode` a device-level capability that works regardless of whether relay support is compiled in. Relay behavior must remain an optional side effect, guarded at the relay-use boundary.

### Concrete Deliverables
- `firmware/components/core/sysload/sysload.c` separates device-mode bootstrap from relay bootstrap.
- `firmware/components/core/device_mode/device_mode.c` guards relay-only behavior with `CONFIG_SA_ENABLE_RELAYS` or an equivalent compile-time-safe abstraction.
- Build/grep evidence proves device mode is no longer hidden behind relay compile flag.

### Definition of Done
- [ ] `handle_device_mode()` is not inside `#if CONFIG_SA_ENABLE_RELAYS`.
- [ ] `device_mode_init(resolved_id)` is not inside `#if CONFIG_SA_ENABLE_RELAYS`.
- [ ] `mqtt_register_command_handler("device_mode", handle_device_mode)` is not inside `#if CONFIG_SA_ENABLE_RELAYS`.
- [ ] `handle_relay_set()`, `relay_init(...)`, and `mqtt_register_command_handler("relay_set", handle_relay_set)` remain relay-gated.
- [ ] With relays disabled, `device_mode_set(false)` does not invoke `relay_force_all_off()` and `device_mode_set(true)` does not invoke `relay_get_all()`.
- [ ] Default ESP-IDF firmware build passes.
- [ ] Relay-disabled build/config check passes or produces explicit evidence of the repo-supported way to verify that matrix.

### Must Have
- Preserve device mode command behavior for `mode="on"` and `mode="off"`.
- Preserve relay behavior when `CONFIG_SA_ENABLE_RELAYS=y`.
- Preserve command registration before `mqtt_start()` to avoid missing queued MQTT commands on connect.
- Keep sensor behavior independent from relay availability.

### Must NOT Have
- Do not edit `.sisyphus/plans/server-hardening-review.md`.
- Do not broaden into full firmware refactor.
- Do not move components or alter CMake unless build failure proves it is required.
- Do not disable `relay_set` compile guards.
- Do not make relay-disabled builds emit relay-dependent calls at runtime.
- Do not introduce new MQTT command types or server contract changes.

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed.

### Test Decision
- **Infrastructure exists**: PARTIAL — ESP-IDF build exists; broad unit-test framework was not confirmed. `firmware/tools/blink/pytest_blink.py` exists but is unrelated to this logic.
- **Automated tests**: Tests-after only if an existing firmware test harness is discovered quickly; otherwise build + static + runtime-smoke evidence.
- **Framework**: ESP-IDF build, static source checks, optional MQTT/mock smoke if executor has an available integration harness.

### QA Policy
Each task captures evidence under `.sisyphus/evidence/`.

---

## Execution Strategy

### Parallel Execution Waves

```text
Wave 1 (Baseline)
└── Task 1: Baseline source/config/build audit [quick]

Wave 2 (Implementation - parallel after Task 1)
├── Task 2: Decouple sysload device-mode bootstrap from relay bootstrap [quick]
└── Task 3: Guard relay side effects inside device_mode.c [quick]

Wave 3 (Integration)
└── Task 4: Build matrix + static QA + command-path evidence [unspecified-high]

Wave FINAL
├── F1: Plan compliance audit (oracle)
├── F2: Firmware code quality review (unspecified-high)
├── F3: Agent-executed QA evidence review (unspecified-high)
└── F4: Scope fidelity check (deep)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|---|---:|---|
| 1 | None | 2, 3, 4 |
| 2 | 1 | 4 |
| 3 | 1 | 4 |
| 4 | 2, 3 | FINAL |
| FINAL | 4 | User approval |

### Agent Dispatch Summary
- Task 1 → `quick` + `esp32s3-component`, `esp32s3-kconfig`, `esp32s3-error`
- Task 2 → `quick` + `esp32s3-component`, `esp32s3-mqtt`, `esp32s3-error`
- Task 3 → `quick` + `esp32s3-component`, `esp32s3-error`
- Task 4 → `unspecified-high` + `esp32s3-component`, `esp32s3-kconfig`, `verification-loop`

---

## TODOs

- [x] 1. Baseline source/config/build audit

  **What to do**:
  - Inspect `firmware/components/core/sysload/sysload.c` around the existing relay-gated handler definitions and runtime-control bootstrap.
  - Inspect `firmware/components/core/device_mode/device_mode.c` for direct relay API usage.
  - Locate Kconfig/config symbol definition for `CONFIG_SA_ENABLE_RELAYS` and determine the safest relay-disabled verification method.
  - Run GitNexus impact checks before implementation if editing `sysload_init`, `handle_device_mode`, or `device_mode_set`.

  **Must NOT do**:
  - Do not edit source files in this task.
  - Do not expand into unrelated CMake/component movement.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: bounded inspection and evidence capture.
  - **Skills**: `esp32s3-component`, `esp32s3-kconfig`, `esp32s3-error`
    - `esp32s3-component`: verify component boundaries and includes.
    - `esp32s3-kconfig`: inspect relay config symbol safely.
    - `esp32s3-error`: keep ESP-IDF error handling expectations in mind.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1
  - **Blocks**: Tasks 2, 3, 4
  - **Blocked By**: None

  **References**:
  - `firmware/components/core/sysload/sysload.c:89-176` - Current handler declarations; `handle_device_mode` is wrongly relay-gated with `handle_relay_set`.
  - `firmware/components/core/sysload/sysload.c:397-426` - Current runtime-control bootstrap wrongly gates `device_mode_init` and device-mode registration behind relay config.
  - `firmware/components/core/device_mode/device_mode.c:83-119` - Shadow publishing path reads relay states directly.
  - `firmware/components/core/device_mode/device_mode.c:200-251` - Mode transition logic; relay side effect appears in `off` path.
  - `firmware/components/core/include/sensor_task.h` - Device mode controls sensor polling independent of relay hardware.
  - `firmware/components/drivers/general/relay/include/relay.h` - Relay API that must remain optional.

  **Acceptance Criteria**:
  - [ ] Evidence file lists all current relay-coupled device-mode points with file:line.
  - [ ] Evidence file identifies how to verify `CONFIG_SA_ENABLE_RELAYS=n` without permanently changing developer config.
  - [ ] GitNexus impact output for planned edited symbols is captured or cited.

  **QA Scenarios**:
  ```text
  Scenario: Baseline coupling evidence
    Tool: Bash + grep or source inspection
    Preconditions: Clean working tree or known local changes documented.
    Steps:
      1. Search `sysload.c` for `handle_device_mode`, `device_mode_init`, `mqtt_register_command_handler("device_mode"`, and nearby `CONFIG_SA_ENABLE_RELAYS` guards.
      2. Search `device_mode.c` for `relay_force_all_off` and `relay_get_all`.
      3. Save matching file:line output.
    Expected Result: Evidence proves the current coupling points exist before changes.
    Failure Indicators: Missing file:line evidence or unclear guard boundaries.
    Evidence: .sisyphus/evidence/task-1-baseline-coupling.txt

  Scenario: Relay config verification path identified
    Tool: Bash/source inspection
    Preconditions: Firmware tree available.
    Steps:
      1. Locate definition/usages of `CONFIG_SA_ENABLE_RELAYS`.
      2. Document the exact command or config-edit approach that will be used for relay-disabled build verification.
    Expected Result: A reproducible relay-disabled verification method is recorded.
    Failure Indicators: Plan proceeds without knowing how relay-disabled verification will be performed.
    Evidence: .sisyphus/evidence/task-1-relay-disabled-method.txt
  ```

  **Commit**: NO

- [x] 2. Decouple `sysload.c` device-mode bootstrap from relay bootstrap

  **What to do**:
  - Move or reorganize `handle_device_mode()` so it is compiled independently of `CONFIG_SA_ENABLE_RELAYS`.
  - Keep `handle_relay_set()` inside `#if CONFIG_SA_ENABLE_RELAYS`.
  - Split the runtime-control bootstrap:
    - Relay block: `buzzer_init()` if still relay-specific, `relay_init(resolved_id)`, `mqtt_register_command_handler("relay_set", handle_relay_set)`.
    - Device-mode block: `device_mode_init(resolved_id)`, `mqtt_register_command_handler("device_mode", handle_device_mode)` outside relay guard.
  - Preserve ordering: device-mode registration must happen before `mqtt_start(...)`.

  **Must NOT do**:
  - Do not ungate `relay_set` command.
  - Do not change MQTT command payload schema.
  - Do not move `mqtt_start()` earlier.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: small single-file structural correction.
  - **Skills**: `esp32s3-component`, `esp32s3-mqtt`, `esp32s3-error`
    - `esp32s3-component`: keep include/component rules clean.
    - `esp32s3-mqtt`: preserve registration-before-connect semantics.
    - `esp32s3-error`: keep ESP-IDF return/log handling consistent.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 with Task 3
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:
  - `firmware/components/core/sysload/sysload.c:89-176` - Source handler placement to correct.
  - `firmware/components/core/sysload/sysload.c:397-426` - Bootstrap block to split.
  - `firmware/components/drivers/general/sa_mqtt/include/mqtt.h:mqtt_register_command_handler` - Registration API.
  - `firmware/components/core/device_mode/device_mode.c:device_mode_init` - Initialization API that must be device-level.

  **Acceptance Criteria**:
  - [ ] `handle_device_mode()` compiles regardless of relay config.
  - [ ] `device_mode_init(resolved_id)` is outside relay guard.
  - [ ] `mqtt_register_command_handler("device_mode", handle_device_mode)` is outside relay guard and before `mqtt_start()`.
  - [ ] Relay bootstrap remains relay-gated.
  - [ ] No duplicate handler registration is introduced.

  **QA Scenarios**:
  ```text
  Scenario: Device-mode bootstrap no longer relay-gated
    Tool: Bash/source inspection
    Preconditions: Task 2 changes applied.
    Steps:
      1. Inspect `sysload.c` around `handle_device_mode` and runtime bootstrap.
      2. Confirm nearest enclosing preprocessor guard is not `CONFIG_SA_ENABLE_RELAYS`.
      3. Confirm `mqtt_register_command_handler("device_mode", handle_device_mode)` appears before `mqtt_start(`.
    Expected Result: Device-mode init and registration are independent of relay config and preserve MQTT startup ordering.
    Failure Indicators: Device-mode symbols still enclosed by relay guard, or registration moves after `mqtt_start`.
    Evidence: .sisyphus/evidence/task-2-sysload-decoupled.txt

  Scenario: Relay command remains relay-only
    Tool: Bash/source inspection
    Preconditions: Task 2 changes applied.
    Steps:
      1. Inspect `handle_relay_set`, `relay_init`, and `mqtt_register_command_handler("relay_set"`.
      2. Confirm all remain under `CONFIG_SA_ENABLE_RELAYS`.
    Expected Result: Relay command remains unavailable in relay-disabled builds.
    Failure Indicators: Relay handler/registration becomes globally compiled without relay support.
    Evidence: .sisyphus/evidence/task-2-relay-still-gated.txt
  ```

  **Commit**: NO

- [x] 3. Guard relay-only side effects inside `device_mode.c`

  **What to do**:
  - Ensure `device_mode_set(false)` only calls `relay_force_all_off()` when relays are enabled.
  - Ensure `publish_mode_on_shadow()` does not call `relay_get_all()` when relays are disabled.
  - Decide and document relay-disabled shadow schema in code comments or implementation notes:
    - Default for this narrow fix: omit relay fields when relays are disabled, unless existing server/app contract strictly requires `relay_1..3` keys.
  - Keep mode-level behavior intact without relays: sensor enable/disable, telemetry/shadow publish, persistence.

  **Must NOT do**:
  - Do not change relay driver semantics.
  - Do not change sensor task API.
  - Do not silently report fake relay states unless explicitly required by existing contract.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: bounded compile-time guard fix in one file.
  - **Skills**: `esp32s3-component`, `esp32s3-error`
    - `esp32s3-component`: ensure relay include/dependency implications are clean.
    - `esp32s3-error`: preserve error propagation for enabled relay failures.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 with Task 2
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:
  - `firmware/components/core/device_mode/device_mode.c:83-119` - `publish_mode_on_shadow()` currently relies on `relay_get_all()`.
  - `firmware/components/core/device_mode/device_mode.c:200-251` - `device_mode_set()` currently calls `relay_force_all_off()` in off path.
  - `firmware/components/drivers/general/relay/include/relay.h` - Optional relay APIs.
  - `firmware/components/core/include/sensor_task.h:sensor_task_set_enabled` - Device-mode behavior independent of relays.

  **Acceptance Criteria**:
  - [ ] Relay-enabled behavior remains unchanged: off path still forces all relays off, on shadow can report relay states.
  - [ ] Relay-disabled behavior has no relay API calls at mode-transition runtime.
  - [ ] `device_mode_set(false)` still stops sensor polling, publishes final/null telemetry, publishes mode-off shadow, and persists mode.
  - [ ] `device_mode_set(true)` still persists mode, enables sensor polling, and publishes mode-on shadow.
  - [ ] Shadow schema for relay-disabled builds is explicit and not accidental.

  **QA Scenarios**:
  ```text
  Scenario: Relay-disabled mode off avoids relay side effects
    Tool: Source inspection + relay-disabled build/static evidence
    Preconditions: Task 3 changes applied.
    Steps:
      1. Inspect `device_mode_set(false)` and any helper it calls.
      2. Confirm `relay_force_all_off()` is under `CONFIG_SA_ENABLE_RELAYS` or equivalent compile-time-safe relay abstraction.
      3. Confirm non-relay operations remain outside the relay guard.
    Expected Result: Mode off remains functional without relay support; relay force-off only exists in relay-enabled code path.
    Failure Indicators: Entire off flow becomes relay-gated, or relay API can execute in relay-disabled build.
    Evidence: .sisyphus/evidence/task-3-off-path-relay-guard.txt

  Scenario: Relay-disabled mode on avoids relay reads
    Tool: Source inspection + relay-disabled build/static evidence
    Preconditions: Task 3 changes applied.
    Steps:
      1. Inspect `publish_mode_on_shadow()`.
      2. Confirm `relay_get_all()` is not called in relay-disabled code path.
      3. Confirm mode-on shadow still includes `mode="on"` and `ts`.
    Expected Result: Mode on shadow publish works without relay hardware/config.
    Failure Indicators: `relay_get_all()` remains unconditional, or mode-on shadow cannot be built without relays.
    Evidence: .sisyphus/evidence/task-3-on-shadow-relay-guard.txt
  ```

  **Commit**: NO

- [x] 4. Build matrix, static QA, and command-path evidence

  **What to do**:
  - Run the default ESP-IDF firmware build.
  - Run a relay-disabled verification path discovered in Task 1.
  - Run static checks proving device-mode code is no longer relay-gated.
  - If an MQTT/integration harness exists, smoke-test `device_mode` command payloads for `mode="off"`, `mode="on"`, invalid JSON, missing `mode`, and unsupported mode value.

  **Must NOT do**:
  - Do not require physical hardware unless an existing repo-supported harness already does so.
  - Do not mark verification complete without evidence files.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: verification spans build matrix, static assertions, and possible command-path smoke checks.
  - **Skills**: `esp32s3-component`, `esp32s3-kconfig`, `verification-loop`
    - `esp32s3-component`: validate component build correctness.
    - `esp32s3-kconfig`: safely toggle/verify relay config.
    - `verification-loop`: ensure evidence completeness.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: FINAL
  - **Blocked By**: Tasks 2, 3

  **References**:
  - `firmware/CMakeLists.txt` - ESP-IDF project entry.
  - `firmware/components/core/sysload/sysload.c` - Main changed integration file.
  - `firmware/components/core/device_mode/device_mode.c` - Main changed behavior file.
  - `firmware/tools/blink/pytest_blink.py` - Example of existing pytest tooling, but not required for this logic unless useful.

  **Acceptance Criteria**:
  - [ ] Default firmware build passes.
  - [ ] Relay-disabled build/config verification passes or records why the current repo lacks an automated relay-disabled matrix path.
  - [ ] Static evidence proves `device_mode` init/handler registration is independent from relay config.
  - [ ] Static evidence proves relay command remains relay-gated.
  - [ ] Static evidence proves relay side effects in `device_mode.c` are relay-gated.
  - [ ] Invalid `device_mode` payload behavior remains error-returning, not silent success.

  **QA Scenarios**:
  ```text
  Scenario: Default firmware build
    Tool: Bash
    Preconditions: ESP-IDF environment available.
    Steps:
      1. Run the repo-standard ESP-IDF build command from Task 1, expected form: `idf.py -C firmware build` or equivalent documented command.
      2. Capture full command and final build result.
    Expected Result: Build completes successfully with no new compile/link errors.
    Failure Indicators: Undefined relay symbols, missing includes, or compile errors in `sysload.c` / `device_mode.c`.
    Evidence: .sisyphus/evidence/task-4-default-build.txt

  Scenario: Relay-disabled verification
    Tool: Bash + ESP-IDF config method from Task 1
    Preconditions: Temporary/restore-safe relay-disabled config method documented.
    Steps:
      1. Apply relay-disabled config in a reversible way.
      2. Run firmware build.
      3. Restore original config if modified.
    Expected Result: Relay-disabled build succeeds and includes device mode support.
    Failure Indicators: Device mode missing, undefined relay symbols, or build requires relay code.
    Evidence: .sisyphus/evidence/task-4-relay-disabled-build.txt

  Scenario: Static guard verification
    Tool: Bash + source inspection
    Preconditions: Tasks 2 and 3 complete.
    Steps:
      1. Produce file:line evidence for `handle_device_mode`, `device_mode_init`, and `mqtt_register_command_handler("device_mode"`.
      2. Produce file:line evidence for `handle_relay_set`, `relay_init`, and `mqtt_register_command_handler("relay_set"`.
      3. Produce file:line evidence around `relay_force_all_off` and `relay_get_all` guards in `device_mode.c`.
    Expected Result: Device-mode paths are ungated; relay paths and relay side effects are guarded.
    Failure Indicators: Any device-mode bootstrap remains under `CONFIG_SA_ENABLE_RELAYS` or relay-specific command becomes ungated.
    Evidence: .sisyphus/evidence/task-4-static-guards.txt
  ```

  **Commit**: YES
  - Message: `fix(firmware): decouple device mode from relay flag`
  - Files: `firmware/components/core/sysload/sysload.c`, `firmware/components/core/device_mode/device_mode.c` if both are changed
  - Pre-commit: default firmware build + relay-disabled verification/static evidence

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit okay before completing.

- [x] F1. **Plan Compliance Audit** — `oracle`
  Verify all Must Have / Must NOT Have items. Confirm evidence files exist and command registration ordering remains before `mqtt_start()`.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Evidence [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Firmware Code Quality Review** — `unspecified-high`
  Review changed firmware files for clean preprocessor boundaries, no duplicated registration, no accidental architecture expansion, and idiomatic ESP-IDF error handling.
  Output: `Build [PASS/FAIL] | Code Quality [PASS/FAIL] | Issues [N] | VERDICT`

- [x] F3. **Agent-Executed QA Evidence Review** — `unspecified-high`
  Re-run or inspect Task 4 evidence. Confirm default and relay-disabled verification were executed or relay-disabled limitation is explicitly documented with static compensating checks.
  Output: `Scenarios [N/N pass] | Evidence [N/N] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  Compare actual diff to this plan. Reject if changes include server code, CMake restructure, MQTT redesign, relay driver semantics rewrite, or unrelated firmware cleanup.
  Output: `Tasks [N/N compliant] | Scope Creep [none/issues] | VERDICT`

---

## Commit Strategy

- **Single commit after Task 4 passes**: `fix(firmware): decouple device mode from relay flag`
- Include only narrow changed files required by the fix.
- Do not commit generated evidence unless repo convention requires it.

---

## Success Criteria

### Verification Commands
```bash
idf.py -C firmware build
# Expected: firmware build passes
```

Relay-disabled verification command must be determined in Task 1 and captured in `.sisyphus/evidence/task-1-relay-disabled-method.txt` before use.

### Final Checklist
- [ ] Device mode compiles/registers independently of relays.
- [ ] Relay command remains relay-gated.
- [ ] Relay side effects inside device mode are optional and compile-time safe.
- [ ] Default build passes.
- [ ] Relay-disabled verification passes or has explicit evidence-backed limitation.
- [ ] No broad firmware/server refactor was included.
