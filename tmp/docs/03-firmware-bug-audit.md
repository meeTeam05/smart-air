# Firmware Bug Audit 03

Date: 2026-05-24

Scope:
- Read `docs/ARCHITECTURE.md`.
- Deep-read firmware runtime paths: `main.c`, `sysload.c`, `config.c`, `mqtt.c`, `httpd.c`, `ble_prov.c`, `wifi.c`, `device_mode.c`, `sensor_task.c`, `relay.c`, `factory_reset.c`, `ota.c`, `adc_bus.c`, `gm702b.c`, `gm102b.c`, `buzzer.c`, `led.c`, `i2cdev.c`, `i2cdev.h`, `config.h`, `mqtt.h`, `Kconfig.projbuild`, `sdkconfig`, `sdkconfig.defaults`, `sdkconfig.demo`.
- Pattern-scanned remaining firmware drivers and empty SPI stubs for hidden alloc/task/error-handling patterns. No additional confirmed issue surfaced from that pass.

Legend:
- Severity: `P1` critical, `P2` major, `P3` minor.
- Type: `Confirmed bug`, `Code smell`, `Intentional tradeoff`.

## Findings

### FW-03-001
- Severity: `P2`
- Type: `Confirmed bug`
- Areas: `Memory`, `MQTT`
- Location: `firmware/components/general/sa_mqtt/mqtt.c:137-156`
- Description: `mqtt_pending_rx_append()` allocates `malloc(total_data_len + 1)` directly from broker-controlled `ev->total_data_len` and applies no upper bound before buffering fragmented payloads.
- Impact: Oversized MQTT payloads on subscribed topics can exhaust heap and reset or destabilize the device before command parsing ever runs. This is a remotely triggerable memory DoS from broker-side traffic.
- Fix suggestion: Add strict per-topic payload caps before allocation, reject oversize frames early, and log/drop or disconnect when `total_data_len` exceeds the accepted limit.
- Disposition: `Fixed in working tree (pending commit)`. `mqtt_pending_rx_append()` now rejects inbound `command`, `shadow/get_response`, and `ota/update` frames above `512` bytes before heap allocation, matching current contract sizes and OTA internal URL bounds.

### FW-03-002
- Severity: `P3`
- Type: `Confirmed bug`
- Areas: `Memory`, `Boot/init sequence`
- Location: `firmware/components/general/wifi/wifi.c:208-215`
- Description: `wifi_sta_init()` creates `s_wifi_eg` first, then returns immediately if `esp_netif_create_default_wifi_sta()` fails. That early return skips cleanup of the already-created event group.
- Impact: Low-memory or partial-init boot failures leak one event group handle per attempt until reboot. Minor in normal boots, but it weakens clean recovery under repeated init stress.
- Fix suggestion: Route all post-allocation failures through the common `fail:` cleanup path or explicitly delete `s_wifi_eg` before the early return.
- Disposition: `Fixed in working tree (pending commit)`. `esp_netif_create_default_wifi_sta()` failure now jumps into the shared `fail:` cleanup path, so the already-created event group is deleted before returning.

### FW-03-003
- Severity: `P2`
- Type: `Confirmed bug`
- Areas: `MQTT`, `Error handling`, `Boot/init sequence`
- Location: `firmware/components/general/sa_mqtt/mqtt.c:701-702`
- Description: `mqtt_task()` ignores return codes from both `esp_mqtt_client_register_event()` and `esp_mqtt_client_start()`. If either step fails, `s_client` remains set and the task deletes itself without surfacing the failure back to `sysload`.
- Impact: Boot can continue as if MQTT started even though no event callbacks or broker session ever come up. Telemetry, command handling, shadow sync, and OTA triggers then fail silently.
- Fix suggestion: Check both return codes, clear `s_client` on failure, destroy the client, and propagate a hard error path so boot can retry or enter an explicit fault state.
- Disposition: `Fixed in working tree (pending commit)`. `mqtt_start()` now waits for `mqtt_task()` to report setup success/failure, while `mqtt_task()` checks `esp_mqtt_client_register_event()` and `esp_mqtt_client_start()`, clears `s_client`, destroys the client, and returns the error to `sysload` on failure.

### FW-03-004
- Severity: `P2`
- Type: `Confirmed bug`
- Areas: `HTTP`, `Power/performance`
- Location: `firmware/components/general/httpd/httpd.c:84-88`
- Description: `config_post_handler()` loops forever on `HTTPD_SOCK_ERR_TIMEOUT` and never enforces a timeout budget or retry ceiling while receiving the POST body.
- Impact: A slow or malicious provisioning client can pin the request handler indefinitely, delaying other work and creating a trivial availability problem during bootstrap. On small systems this also increases watchdog risk because provisioning never fails closed.
- Fix suggestion: Track elapsed time or retry count, abort after a bounded receive budget, and return an explicit `408` or `400` JSON error.
- Disposition: `Fixed in working tree (pending commit)`. `config_post_handler()` now aborts after three consecutive `HTTPD_SOCK_ERR_TIMEOUT` results, logs the stalled receive state, and returns `408 Request Timeout` JSON instead of looping forever.

### FW-03-005
- Severity: `P2`
- Type: `Confirmed bug`
- Areas: `HTTP`, `Error handling`
- Location: `firmware/components/general/httpd/httpd.c:89-90`
- Description: Non-timeout `httpd_req_recv()` failures return raw `ESP_FAIL` without sending any HTTP response body or status code.
- Impact: Provisioning clients see a dropped/opaque failure instead of a machine-readable reason, which makes retry logic unreliable and obscures production diagnostics.
- Fix suggestion: Map receive failures to explicit HTTP error responses when the socket is still usable, and log the failing receive state for postmortem analysis.
- Disposition: `Fixed in working tree (pending commit)`. Non-timeout `httpd_req_recv()` failures in `config_post_handler()` now log the receive state and attempt a `400 Bad Request` JSON response instead of returning raw `ESP_FAIL`.

### FW-03-006
- Severity: `P1`
- Type: `Intentional tradeoff`
- Areas: `HTTP`, `Security`
- Location: `firmware/components/general/httpd/httpd.c:76-146`, `firmware/components/general/httpd/httpd.c:173-186`, `firmware/sdkconfig:574`
- Description: Local provisioning accepts `device_id`, `broker_uri`, and `secret_key` over unauthenticated plain HTTP using `esp_http_server` on port `80`. There is no TLS, no request authentication, and no one-time bootstrap token in firmware.
- Impact: Any actor on the same LAN during first-time provisioning can race the legitimate installer, inject a rogue MQTT secret, or sniff the device secret in transit if the local network is not fully trusted.
- Fix suggestion: Replace this with an authenticated bootstrap path such as secured BLE pairing plus one-time token, temporary AP + HTTPS, or another authenticated local trust handshake. If this tradeoff is intentionally accepted, document the threat model and deployment assumptions explicitly.
- Disposition: `Intentional tradeoff documented`. Repo still uses local `POST http://<device-ip>/api/config` with no transport/auth protection, so no safe minimal firmware-only fix exists in this audit slice. Added explicit trusted-LAN threat-model notes in `docs/API_REFERENCE.md`, `docs/MQTT_PROTOCOL.md`, and `docs/ARCHITECTURE.md`; redesign remains product/security follow-up.

### FW-03-007
- Severity: `P1`
- Type: `Confirmed bug`
- Areas: `BLE`, `Security`
- Location: `firmware/components/general/ble_prov/ble_prov.c:117-123`, `firmware/components/general/ble_prov/ble_prov.c:171-206`, `firmware/components/general/ble_prov/ble_prov.c:434-435`
- Description: BLE provisioning exposes writable SSID/password characteristics with plain `WRITE`/`WRITE_NO_RSP` permissions and configures no pairing, bonding, MITM, or encryption gates before accepting credential writes.
- Impact: Any nearby BLE client can provision rogue Wi-Fi credentials or hijack first-boot onboarding. This is a direct local-radio takeover path during provisioning.
- Fix suggestion: Require authenticated encrypted BLE sessions before write access, enable bonding/MITM protection, and reject provisioning writes until the connection satisfies the chosen security level.
- Disposition: `Blocked pending human judgment`. Current repo has no authenticated BLE pairing flow in firmware or app onboarding, so flipping NimBLE security requirements would change provisioning UX and likely require app changes. Added explicit radio-range trust assumptions in `docs/ARCHITECTURE.md` and `docs/API_REFERENCE.md`; secure-BLE redesign remains follow-up work.

### FW-03-008
- Severity: `P1`
- Type: `Confirmed bug`
- Areas: `Config/NVS`, `Security`
- Location: `firmware/components/general/ble_prov/ble_prov.c:153-161`, `firmware/components/config/config.c:281-289`, `firmware/sdkconfig:2208`, `firmware/sdkconfig:2499`
- Description: Firmware persists Wi-Fi password and MQTT `secret_key` to NVS in plaintext, while current build config has both `CONFIG_NVS_ENCRYPTION` and `CONFIG_FLASH_ENCRYPTION_ENABLED` disabled.
- Impact: Anyone with flash access, debug access, or a raw storage dump can recover network and broker credentials. That turns physical access or service-chain exposure into long-lived credential compromise.
- Fix suggestion: Enable flash encryption and NVS encryption in the manufacturing/runtime flow, or move secrets to hardware-backed secure storage and update provisioning/reset flows accordingly.
- Disposition: `Blocked pending human judgment`. Repo truth confirms plaintext secret storage and disabled `CONFIG_NVS_ENCRYPTION` / `CONFIG_FLASH_ENCRYPTION_ENABLED`, but enabling those protections safely needs manufacturing key provisioning, flash/OTA compatibility review, and deployment-flow changes beyond a narrow firmware patch. Added explicit storage-assumption notes in `docs/MQTT_PROTOCOL.md` and `docs/ARCHITECTURE.md`.

### FW-03-009
- Severity: `P2`
- Type: `Confirmed bug`
- Areas: `Error handling`, `Boot/init sequence`
- Location: `firmware/components/general/wifi/wifi.c:237-238`, `firmware/components/general/wifi/wifi.c:372-381`, `firmware/components/general/factory_reset/factory_reset.c:62`
- Description: Wi-Fi init/deinit paths use `ESP_ERROR_CHECK()` for operations that can legitimately fail with recoverable or benign states, including cleanup during factory reset. `factory_reset_run()` depends on `wifi_sta_deinit()`, so a not-connected or invalid-state Wi-Fi call can abort the whole firmware instead of returning an error.
- Impact: Factory reset and boot recovery paths can crash before NVS erase finishes, leaving the device stuck in a fault loop or partially reset state under real-world Wi-Fi failures.
- Fix suggestion: Replace `ESP_ERROR_CHECK()` with explicit `esp_err_t` handling, tolerate benign cleanup states such as already-disconnected/stopped, and propagate errors back to callers instead of aborting.
- Disposition: `Fixed in working tree (pending commit)`. `wifi_sta_deinit()` now logs and tolerates benign Wi-Fi cleanup states instead of aborting, returns the first real teardown error, and `factory_reset_run()` logs that error but continues erasing NVS/rebooting.

### FW-03-010
- Severity: `P3`
- Type: `Code smell`
- Areas: `Power/performance`, `Boot/init sequence`
- Location: `firmware/components/core/sysload/sysload.c:197-203`, `firmware/components/core/sysload/sysload.c:979-985`
- Description: Boot performs synchronous SNTP wait before MQTT start, OTA task start, and sensor task start. With current config this can block the boot path for up to `CONFIG_SA_SNTP_SYNC_TIMEOUT_MS` even though the architecture treats SNTP as best-effort.
- Impact: DNS or NTP slowness adds predictable startup delay, postponing provisioning HTTP availability, command handling, telemetry, and OTA validation without improving correctness when fallback clocks already exist.
- Fix suggestion: Start SNTP asynchronously, continue boot immediately, and update RTC/system time in a background callback once sync completes.

### FW-03-011
- Severity: `P3`
- Type: `Confirmed bug`
- Areas: `Memory`, `Error handling`
- Location: `firmware/components/core/sysload/sysload.c:302-312`
- Description: `calibration_task_start()` allocates `s_calibration_queue`, then returns `ESP_FAIL` if `xTaskCreatePinnedToCore()` fails without deleting the queue or clearing the global pointer.
- Impact: Rare low-memory task-start failures leak queue memory until reboot and make repeated recovery attempts less deterministic.
- Fix suggestion: On task-create failure, call `vQueueDelete(s_calibration_queue)`, set the pointer back to `NULL`, and return the failure.

### FW-03-012
- Severity: `P3`
- Type: `Confirmed bug`
- Areas: `HTTP`, `Error handling`
- Location: `firmware/components/general/httpd/httpd.c:182-183`
- Description: `httpd_server_start()` ignores return codes from `httpd_register_uri_handler()` for both provisioning endpoints.
- Impact: If URI registration fails, the function still reports success and the boot path continues without a working `/api/info` or `/api/config` endpoint.
- Fix suggestion: Check both registration calls, stop the HTTP server on failure, and propagate the error to `sysload` so bootstrap does not continue in a half-started state.

## Checklist Coverage

- Memory: `FW-03-001`, `FW-03-002`, `FW-03-011`
- Concurrency: `No issue found` in current static audit. Shared-state usage in reviewed runtime modules is simple and mostly guarded; no confirmed race, deadlock, or ISR-safety bug was proven from code alone.
- MQTT: `FW-03-001`, `FW-03-003`
- HTTP: `FW-03-004`, `FW-03-005`, `FW-03-006`, `FW-03-012`
- BLE: `FW-03-007`
- Config/NVS: `FW-03-008`
- Error handling: `FW-03-003`, `FW-03-005`, `FW-03-009`, `FW-03-011`, `FW-03-012`
- Security: `FW-03-006`, `FW-03-007`, `FW-03-008`
- Power/performance: `FW-03-010`
- Boot/init sequence: `FW-03-003`, `FW-03-009`, `FW-03-010`

## Notes

- `FW-03-006` is real risk, but final acceptability depends on product threat model and deployment assumptions. Static code proves lack of transport/auth protection; it cannot decide whether that tradeoff is acceptable for intended rollout.
- No hardware-only blocker was required to confirm the findings above. Hardware/runtime testing would still be useful later to quantify watchdog behavior for `FW-03-004` and user-visible reset behavior for `FW-03-009`.
