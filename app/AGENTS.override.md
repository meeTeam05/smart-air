# app/AGENTS.override.md

Codex instructions for `app/`.

## Stack

Flutter mobile app for iOS/Android.

Key packages:

- `flutter_riverpod` for state management.
- `go_router` for navigation.
- `dio` for HTTP.
- `freezed` and `json_serializable` for models.
- `flutter_blue_plus`, `permission_handler`, and `wifi_scan` for provisioning.
- `fl_chart` for charts.

## Required Context

Before app edits:

1. Read `../docs/CONSTRAINTS.md`.
2. Inspect nearby widgets/providers/services before adding new patterns.
3. Check GitNexus impact before editing named widgets, providers, services, models, or route functions.

## Hard Rules

- In every `build()` method, first line should be `final c = context.colors;`.
- Do not directly use adaptive colors in `build()` methods:
  - `AppColors.bg`
  - `AppColors.surface`
  - `AppColors.border`
  - `AppColors.textPrimary`
  - `AppColors.textSecondary`
  - `AppColors.surfaceVar`
- Use `context.colors` for adaptive colors.
- Non-adaptive `AppColors.primary`, `AppColors.online`, `AppColors.offline`, and `AppColors.warning` may be used directly.
- Do not hand-edit generated files ending in `.freezed.dart` or `.g.dart`.
- JWT access tokens stay in memory only.
- Refresh tokens belong in secure storage.
- Send JWTs only as `Authorization: Bearer <token>`, never in URLs.

## UI Rules

- Match the existing design system under `lib/design/` and existing widgets before adding new components.
- Prefer lucide icons where the app already uses icons.
- Keep operational screens dense, scannable, and predictable.
- Avoid marketing-style hero layouts for app workflows.
- Ensure text does not overflow on narrow devices.
- Keep widget tests and golden tests deterministic.

## Commands

Run from `app/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
flutter build ios --release
dart run build_runner build --delete-conflicting-outputs
dart fix --apply
```

Use RTK from the repo root when launching through Codex, for example:

```bash
rtk proxy flutter analyze
rtk proxy flutter test
```

## Verification

- Run `flutter analyze` for Dart changes.
- Run focused `flutter test` targets for changed screens, providers, services, or models.
- Run build runner after changing Freezed or JSON model sources.
- If mobile SDKs or emulators are unavailable, report the blocked command and remaining risk.
