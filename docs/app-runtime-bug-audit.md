# App Runtime Bug Audit

Scope: `app/` Flutter mobile app only. This is a read-only audit of current runtime behavior, state management, UI logic, API response handling, race conditions, and reachable edge cases. No fixes were applied.

Verification snapshot:
- `cd app && rtk proxy flutter analyze`
  - Result: passed with 27 info-level lint issues, no blocking analyzer errors.
- `cd app && rtk proxy flutter test`
  - Result: 54 tests passed.
  - Warnings: golden tag is used without `dart_test.yaml`.

Those checks do not cover the runtime defects below. Most current tests are UI smoke/golden coverage and do not exercise live command completion, provider cache invalidation, or provisioning recovery paths.

## Findings

### 1. High: dashboard sensor values are not real-time and drift from runtime state

Known issue confirmed.

Evidence:
- Dashboard reads current sensor cards from shadow `reported`, not from the latest telemetry point: [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:58), [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:61), [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:69)
- Historical sparkline data comes from a separate telemetry fetch: [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:74)
- The app production flow uses REST snapshots for shadow and telemetry, not a live WSS stream: [docs/API_REFERENCE.md](/home/nhat/Working_Space/my-project/smart-air/docs/API_REFERENCE.md:810)
- Telemetry is the server’s real-time sensor stream: [docs/API_REFERENCE.md](/home/nhat/Working_Space/my-project/smart-air/docs/API_REFERENCE.md:745), [docs/API_REFERENCE.md](/home/nhat/Working_Space/my-project/smart-air/docs/API_REFERENCE.md:818)

Impact:
- Sensor tiles can show stale shadow values while sparklines show newer telemetry points.
- Leaving the dashboard open without pull-to-refresh causes visible divergence from actual runtime values.

Why it happens:
- `shadowProvider` and `telemetryProvider` are fetched once and only refreshed manually or after local actions. There is no periodic polling or subscription path for open dashboards: [app/lib/providers/devices_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/devices_provider.dart:49), [app/lib/providers/devices_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/devices_provider.dart:88)

### 2. High: relay and mode toggles race command execution and refresh shadow too early

Known issue confirmed.

Evidence:
- Mode toggle posts command, then immediately refreshes shadow: [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:418), [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:420)
- Relay toggle does the same: [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:451), [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:455)
- The app already has a correct async pattern for long-running commands in calibration flow: send command, then wait for command completion status before updating UI: [app/lib/screens/devices/settings/calibration_wizard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/settings/calibration_wizard_screen.dart:364), [app/lib/screens/devices/settings/calibration_wizard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/settings/calibration_wizard_screen.dart:369)
- Command completion is explicitly available in the service layer: [app/lib/services/device_service.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/services/device_service.dart:282)

Impact:
- Relay toggles can appear to lag, flicker back, or overlap when shadow refreshes before the device has executed the command and published the updated shadow.
- Mode toggle can temporarily show the old state after user action.

### 3. High: recent activity panel does not update after relay or mode actions

Evidence:
- Dashboard reads recent commands from `commandsProvider`: [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:76)
- Relay/mode handlers bypass `commandsProvider.send()` and never invalidate `commandsProvider` after sending commands: [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:419), [app/lib/screens/devices/device_dashboard_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_dashboard_screen.dart:454)
- `commandsProvider` only invalidates itself when its own `send()` helper is used: [app/lib/providers/devices_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/devices_provider.dart:81)

Impact:
- User sends a relay/mode command, but “Recent activity” remains stale until manual pull-to-refresh.
- This compounds the toggle-race bug by hiding whether the command actually entered the queue or finished.

### 4. High: provisioning retry path breaks after partial success because `409 Device already registered` is not recovered

Evidence:
- Provisioning step 3 always calls `provisionDevice()` and treats any error as fatal: [app/lib/screens/provision/step3_wifi.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/step3_wifi.dart:78), [app/lib/screens/provision/step3_wifi.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/step3_wifi.dart:81)
- API contract explicitly returns `409 "Device already registered"` from `POST /api/devices`: [docs/API_REFERENCE.md](/home/nhat/Working_Space/my-project/smart-air/docs/API_REFERENCE.md:430), [docs/API_REFERENCE.md](/home/nhat/Working_Space/my-project/smart-air/docs/API_REFERENCE.md:473)
- Older provisioning flow already knew this was a recoverable case and handled `409`: [app/lib/screens/provision/wifi_setup_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/wifi_setup_screen.dart:93), [app/lib/screens/provision/wifi_setup_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/wifi_setup_screen.dart:96)

Impact:
- If server registration succeeds but local `configureProvisionedDevice()` fails, the user can get stuck on all retries because the next registration attempt returns 409 and the app stops instead of continuing the flow.

### 5. Medium: cloud announce step can hang forever and aborts on the first transient error

Evidence:
- Step 4 starts a periodic poll every 2 seconds with no overall timeout or max attempt limit: [app/lib/screens/provision/step4_cloud.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/step4_cloud.dart:50), [app/lib/screens/provision/step4_cloud.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/step4_cloud.dart:64)
- Any transient exception immediately cancels polling and drops the flow into an error state: [app/lib/screens/provision/step4_cloud.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/step4_cloud.dart:78), [app/lib/screens/provision/step4_cloud.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/provision/step4_cloud.dart:80)

Impact:
- If the backend never announces and never errors, the screen can spin indefinitely.
- If one poll hits a temporary network/API hiccup, the app fails the entire provisioning confirmation flow instead of retrying through a bounded wait window.

### 6. Medium: provider caches survive logout and can leak stale device state into the next session

Evidence:
- Forced logout only invalidates `devicesProvider` and `homesProvider`: [app/lib/providers/auth_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/auth_provider.dart:23), [app/lib/providers/auth_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/auth_provider.dart:25)
- Manual logout invalidates nothing except auth state: [app/lib/providers/auth_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/auth_provider.dart:65)
- `shadowProvider`, `commandsProvider`, and `telemetryProvider` are long-lived family providers, not auto-dispose providers: [app/lib/providers/devices_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/devices_provider.dart:49), [app/lib/providers/devices_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/devices_provider.dart:68), [app/lib/providers/devices_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/devices_provider.dart:88)

Impact:
- After logout/login as another user, old shadow/telemetry/command state can remain cached until each provider happens to refetch.
- This is a real session-isolation bug, not just stale UI.

### 7. Medium: home cards show raw room IDs instead of room names

Evidence:
- Device card renders `device.roomId` directly to the user: [app/lib/widgets/device_card.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/widgets/device_card.dart:84), [app/lib/widgets/device_card.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/widgets/device_card.dart:85)
- The app already has room-name data sources through `roomsProvider` and room models: [app/lib/providers/homes_provider.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/providers/homes_provider.dart:44)

Impact:
- Users see opaque UUID/ID values instead of human room labels in the main device list.
- This is a current user-facing data-mapping bug.

### 8. Medium: general settings screen can get stuck in an infinite loading spinner on provider error or deleted device state

Evidence:
- Settings screen resolves the target device from `devicesProvider.valueOrNull`, then shows a loading spinner whenever the device is null: [app/lib/screens/devices/settings/general_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/settings/general_screen.dart:42), [app/lib/screens/devices/settings/general_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/settings/general_screen.dart:46)
- It does not branch on `devicesAsync.hasError` or “device not found” as a separate terminal state.

Impact:
- If device loading fails or the device disappears from the list, the user sees a permanent spinner instead of an actionable error or back path.

### 9. Medium: chart screen time window goes stale while the screen stays open

Evidence:
- Chart params are computed once in `initState()` using the current time: [app/lib/screens/devices/device_chart_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_chart_screen.dart:33), [app/lib/screens/devices/device_chart_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_chart_screen.dart:36)
- The screen watches `telemetryProvider(_params)` and does not poll or auto-slide the time range forward while the user keeps the screen open: [app/lib/screens/devices/device_chart_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_chart_screen.dart:63), [app/lib/screens/devices/device_chart_screen.dart](/home/nhat/Working_Space/my-project/smart-air/app/lib/screens/devices/device_chart_screen.dart:66)

Impact:
- A “last 1h / 24h” chart silently becomes “1h ending when the screen opened”, so new telemetry stops appearing unless the user manually changes range or leaves/re-enters.

## Lower-confidence observations not counted as primary findings

- `app/lib/screens/provision/wifi_setup_screen.dart` and `app/lib/widgets/add_device_sheet.dart` contain obsolete/placeholder flows, including simulated discovery. They are not currently routed from the active home/provisioning flow, so they were not counted as current runtime defects.
- OTA screen is intentionally read-only today. That is a product gap, not a runtime bug by itself.

## Current Coverage Gaps

Tests currently miss the failure modes above:
- No test covers relay/mode command completion timing or shadow refresh ordering.
- No test covers provisioning retry after server-side partial registration.
- No test covers logout cache invalidation across provider families.
- No test covers stale dashboard/chart data while screens remain open.

## Audit Summary

High-confidence current app bugs found in reachable flows: 9

Most severe clusters:
- dashboard/runtime state freshness
- relay/mode command response handling
- provisioning recovery and announce polling
- logout/session cache isolation
