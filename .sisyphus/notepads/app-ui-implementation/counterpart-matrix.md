# Screen Counterpart Matrix — 390dp Verification

**Generated:** 2026-05-11  
**Purpose:** Map every mockup screen in `tmp/app/` to its Flutter counterpart for 390dp visual parity verification.

---

## Mockup Source Files

| File | Screens Count | Notes |
|------|---------------|-------|
| `screens-auth.jsx` | 3 | Splash, Login, Register |
| `screens-home-dash.jsx` | 4 | Home Empty, Home Populated, Dashboard On, Dashboard Standby |
| `screens-charts-history.jsx` | 2 | Charts, Command History |
| `screens-settings-ble.jsx` | 8 | General Settings, Calibration Wizard (3 steps), OTA, BLE Provisioning (5 steps) |
| `screens-auto-notif-profile.jsx` | 3 | Automation, Notifications, Profile |
| **TOTAL** | **20** | 20 unique screen states |

---

## Counterpart Mapping

### Auth Flow (3 screens)

| Mockup Component | Flutter Screen | Route | Status |
|------------------|----------------|-------|--------|
| `AuthSplash` | `app/lib/screens/auth/splash_screen.dart` | `/` | ✅ MAPPED |
| `AuthLogin` | `app/lib/screens/auth/login_screen.dart` | `/login` | ✅ MAPPED |
| `AuthRegister` | `app/lib/screens/auth/register_screen.dart` | `/register` | ✅ MAPPED |

### Home Tab (2 screens)

| Mockup Component | Flutter Screen | Route | Status |
|------------------|----------------|-------|--------|
| `HomeEmpty` | `app/lib/screens/home_screen.dart` (empty state) | `/home` | ✅ MAPPED |
| `HomePopulated` | `app/lib/screens/home_screen.dart` (populated state) | `/home` | ✅ MAPPED |

### Device Dashboard (2 screens)

| Mockup Component | Flutter Screen | Route | Status |
|------------------|----------------|-------|--------|
| `DeviceDashboard` (mode=on) | `app/lib/screens/devices/device_dashboard_screen.dart` (on state) | `/devices/:id` | ✅ MAPPED |
| `DeviceDashboard` (mode=standby) | `app/lib/screens/devices/device_dashboard_screen.dart` (standby state) | `/devices/:id` | ✅ MAPPED |

### Charts & History (2 screens)

| Mockup Component | Flutter Screen | Route | Status |
|------------------|----------------|-------|--------|
| `ChartScreen` | `app/lib/screens/devices/device_chart_screen.dart` | `/devices/:id/chart` | ✅ MAPPED |
| `CommandHistoryScreen` | `app/lib/screens/devices/command_history_screen.dart` | `/devices/:id/commands` | ✅ MAPPED |

### Device Settings (3 screens)

| Mockup Component | Flutter Screen | Route | Status |
|------------------|----------------|-------|--------|
| `SettingsGeneral` | `app/lib/screens/devices/settings/general_screen.dart` | `/devices/:id/settings` | ✅ MAPPED |
| `CalibrationWizard` (3 steps) | `app/lib/screens/devices/settings/calibration_wizard_screen.dart` | `/devices/:id/calibrate/:sensor` | ✅ MAPPED |
| `OtaScreen` | `app/lib/screens/devices/settings/ota_screen.dart` | `/devices/:id/ota` | ✅ MAPPED |

### BLE Provisioning (5 screens)

| Mockup Component | Flutter Screen | Route | Status |
|------------------|----------------|-------|--------|
| `Ble1` (power on) | `app/lib/screens/provision/step1_power_on.dart` | `/provision` | ✅ MAPPED |
| `Ble2` (scan) | `app/lib/screens/provision/step2_ble_scan.dart` | `/provision/scan` | ✅ MAPPED |
| `Ble3` (wifi) | `app/lib/screens/provision/step3_wifi.dart` | `/provision/wifi` | ✅ MAPPED |
| `Ble4` (cloud) | `app/lib/screens/provision/step4_cloud.dart` | `/provision/announce` | ✅ MAPPED |
| `Ble5` (name) | `app/lib/screens/provision/step5_name.dart` | `/provision/name` | ✅ MAPPED |

### Tabs (3 screens)

| Mockup Component | Flutter Screen | Route | Status |
|------------------|----------------|-------|--------|
| `AutomationTab` | `app/lib/screens/automation_screen.dart` | `/automation` | ✅ MAPPED |
| `NotificationsTab` | `app/lib/screens/notifications_screen.dart` | `/notifications` | ✅ MAPPED |
| `ProfileTab` | `app/lib/screens/profile/profile_screen.dart` | `/profile` | ✅ MAPPED |

---

## Summary

- **Total mockup screens:** 20
- **Mapped Flutter counterparts:** 20
- **Missing counterparts:** 0
- **Coverage:** 100%

---

## 390dp Verification Strategy

Since browser-based visual QA is blocked in this environment (Chrome unavailable), verification will use:

1. **Widget test viewport constraints** — render each screen in a 390dp-wide test surface
2. **Layout presence checks** — verify critical UI elements exist and are positioned correctly
3. **Deterministic assertions** — check widget tree structure, not pixel-perfect rendering

### Test Coverage Plan

Create `app/test/counterpart_390dp_test.dart` with:
- One test group per mockup section (Auth, Home, Dashboard, etc.)
- Each test renders the Flutter screen in a 390dp-wide ConstrainedBox
- Assertions verify presence of hero elements (titles, buttons, cards, navigation)
- Tests run in both light and dark themes

This approach provides objective counterpart verification without requiring visual browser QA.
