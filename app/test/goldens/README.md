# Golden Test Baseline

This directory contains golden test infrastructure for visual regression testing of Atmosphere design system atoms and primary screens.

## Status

**BASELINE COMMITTED, CURRENTLY DRIFTED**

- Font assets bundled locally (`assets/fonts/`) — no network dependency
- 18 baseline images are committed in `test/goldens/goldens/`
- Default `flutter test` currently passes 54 tests
- As of 2026-05-14, `flutter test --dart-define=RUN_GOLDENS=true test/goldens/` still fails on:
  - `screen_login_light.png` (`17.33%`, `57031px` diff)
  - `screen_login_dark.png` (`17.32%`, `57004px` diff)
  - `screen_home_populated_light.png` (`0.74%`, `2425px` diff)
- Failure artifacts are written to `test/goldens/failures/`

## Structure

```
test/goldens/
├── atoms_golden_test.dart   — 13 golden tests for atom widgets
├── screens_golden_test.dart — 5 golden tests for primary screens
├── goldens/                 — Baseline PNG images (committed)
│   ├── atoms_buttons_light.png
│   ├── atoms_buttons_dark.png
│   ├── atoms_cards_light.png
│   ├── atoms_dot_logo_light.png
│   ├── atoms_empty_state_light.png
│   ├── atoms_filter_chips_light.png
│   ├── atoms_form_elements_light.png
│   ├── atoms_history_row_light.png
│   ├── atoms_mode_card_light.png
│   ├── atoms_pills_light.png
│   ├── atoms_relay_cards_light.png
│   ├── atoms_sensor_tiles_light.png
│   ├── atoms_step_dots_light.png
│   ├── screen_home_empty_light.png
│   ├── screen_home_populated_light.png
│   ├── screen_login_dark.png
│   ├── screen_login_light.png
│   └── screen_profile_light.png
└── README.md                — This file
```

Also referenced: `test/flutter_test_config.dart` — GoldenToolkit configuration

## Test Coverage

### Atoms (13 tests)
| Test Name | Golden File |
|-----------|-------------|
| Buttons - light theme | `atoms_buttons_light.png` |
| Buttons - dark theme | `atoms_buttons_dark.png` |
| Pills - all tones (6 variants) | `atoms_pills_light.png` |
| Cards (basic + gradient) | `atoms_cards_light.png` |
| Sensor Tiles - all tones (warm/air/cool/no2) | `atoms_sensor_tiles_light.png` |
| Relay Cards (on/off/disabled) | `atoms_relay_cards_light.png` |
| Mode Card (on + standby) | `atoms_mode_card_light.png` |
| Form Elements (field + switch) | `atoms_form_elements_light.png` |
| History Row (with/without badge) | `atoms_history_row_light.png` |
| Filter Chips (active/inactive) | `atoms_filter_chips_light.png` |
| Step Dots (progress indicators) | `atoms_step_dots_light.png` |
| Empty State (with CTA) | `atoms_empty_state_light.png` |
| Dot Logo (brand color) | `atoms_dot_logo_light.png` |

### Screens (5 tests)
| Test Name | Golden File |
|-----------|-------------|
| Login Screen - light theme | `screen_login_light.png` |
| Login Screen - dark theme | `screen_login_dark.png` |
| Home Screen - empty state | `screen_home_empty_light.png` |
| Home Screen - with 3 devices | `screen_home_populated_light.png` |
| Profile Screen | `screen_profile_light.png` |

## Usage

### Run Default Test Suite (Excludes Golden Tests)
```bash
cd app
flutter test
```
Runs all 54 widget/unit/theme tests. Golden tests are **skipped by default** — this command is always safe to run.

### Run Golden Tests (Verify Against Baselines)
```bash
cd app
flutter test --dart-define=RUN_GOLDENS=true test/goldens/
```
Runs all 18 golden tests and compares against committed baselines. All 18 should pass.
At the moment, the command is expected to fail on the three known screen baselines listed above until the visuals or baselines are updated intentionally.

### Regenerate Golden Baselines
```bash
cd app
flutter test --dart-define=RUN_GOLDENS=true --update-goldens test/goldens/
```
Overwrites the baseline images in `test/goldens/goldens/`. Run this only when you intentionally change widget appearance. **Always commit the updated baselines along with the code change.**

### Update a Single Golden
```bash
cd app
# Update atoms only
flutter test --dart-define=RUN_GOLDENS=true --update-goldens test/goldens/atoms_golden_test.dart

# Update screens only
flutter test --dart-define=RUN_GOLDENS=true --update-goldens test/goldens/screens_golden_test.dart
```

## Font Asset Setup

Fonts are bundled in `assets/fonts/` and declared in `pubspec.yaml` under the `flutter.fonts` section. This eliminates the Google Fonts network dependency during tests.

**Bundled fonts:**
- `PlusJakartaSans-Regular.ttf` (w400)
- `PlusJakartaSans-Medium.ttf` (w500)
- `PlusJakartaSans-SemiBold.ttf` (w600)
- `PlusJakartaSans-Bold.ttf` (w700)
- `JetBrainsMono-Regular.ttf` (w400)

The `google_fonts` package automatically uses these local assets when they are registered in the asset manifest (via `pubspec.yaml`), bypassing any network fetch.

## Implementation Notes

### Continuous Animation Handling
Some widgets use continuous animations (e.g. `CircularProgressIndicator` in `PrimaryButton.loading`, `TweenAnimationBuilder` in `SensorTile`). These would cause `pumpAndSettle()` to time out. The affected tests use `customPump: (t) => t.pump(const Duration(milliseconds: 300))` to capture a deterministic frame.

Tests using `customPump`:
- `Buttons - light/dark` (PrimaryButton loading spinner)
- `Sensor Tiles` (TweenAnimationBuilder)
- `Mode Card` (AtmosphereSwitch animation)

### Layout Constraints for Atom Tests
Atoms are tested with explicit `surfaceSize` and (where needed) explicit `SizedBox` dimensions:
- `SensorTile` requires bounded height (uses `Spacer()` internally) — wrapped in `SizedBox(height: 150)` and laid out in a single column.
- `RelayCard` height set to 200 (was 150, overflowed by 16px).
- `Mode Card` surface height set to 420 (was 300, overflowed by 96px).
- `Empty State` surface height set to 460 (was 300, overflowed by 141px).

These are **test-side wrapper adjustments only** — production widget behavior is unchanged.

## Integration with CI

### Standard CI (Recommended)
```yaml
- name: Run Tests
  run: |
    cd app
    flutter test   # Golden tests skipped by default
```

### CI with Golden Verification
```yaml
- name: Run All Tests Including Golden
  run: |
    cd app
    flutter test --dart-define=RUN_GOLDENS=true test/goldens/   # Golden tests
    flutter test                                                  # Standard tests
```

**Important:** Golden images are platform-specific. Baselines generated on Linux **will fail** on macOS or Windows. Run `--update-goldens` on the same OS as your CI environment.

## Notes

- Golden tests use `bool.fromEnvironment('RUN_GOLDENS')` to skip by default
- Tests are tagged `@Tags(['golden'])` for organizational identification
- Golden images are platform-specific (Linux != macOS != Windows)
- Use `--update-goldens` only when intentionally updating baselines
- Review golden diffs carefully before committing updated baselines
- Golden tests complement but do not replace manual visual QA
