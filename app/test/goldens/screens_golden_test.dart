@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:smart_air/app_theme.dart';
import 'package:smart_air/models/device.dart' as app_models;
import 'package:smart_air/models/home.dart';
import 'package:smart_air/screens/auth/login_screen.dart';
import 'package:smart_air/screens/home_screen.dart';
import 'package:smart_air/screens/profile/profile_screen.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';

void main() {
  const runGoldens = bool.fromEnvironment('RUN_GOLDENS', defaultValue: false);
  
  group('Primary Screens Golden Baseline', () {
    testGoldens('Login Screen - light theme', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        const LoginScreen(),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(390, 844),
      );

      await screenMatchesGolden(tester, 'screen_login_light');
    });

    testGoldens('Login Screen - dark theme', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        const LoginScreen(),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.dark()),
        surfaceSize: const Size(390, 844),
      );

      await screenMatchesGolden(tester, 'screen_login_dark');
    });

    testGoldens('Home Screen - empty state', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(devices: const []),
            ),
          ],
          child: const HomeScreen(),
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(390, 844),
      );

      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'screen_home_empty_light');
    });

    testGoldens('Home Screen - with devices', (tester) async {
      if (!runGoldens) return;
      final mockDevices = [
        app_models.Device(
          id: 'device-1',
          name: 'Living Room',
          homeId: 'home-1',
          roomId: 'room-1',
          online: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        app_models.Device(
          id: 'device-2',
          name: 'Bedroom',
          homeId: 'home-1',
          roomId: 'room-2',
          online: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        app_models.Device(
          id: 'device-3',
          name: 'Kitchen',
          homeId: 'home-1',
          roomId: 'room-3',
          online: false,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidgetBuilder(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(devices: mockDevices),
            ),
          ],
          child: const HomeScreen(),
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(390, 844),
      );

      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'screen_home_populated_light');
    });

    testGoldens('Profile Screen', (tester) async {
      if (!runGoldens) return;
      await tester.pumpWidgetBuilder(
        ProviderScope(
          overrides: [
            homeServiceProvider.overrideWithValue(
              _FakeHomeService(homes: const []),
            ),
          ],
          child: const ProfileScreen(),
        ),
        wrapper: materialAppWrapper(theme: AtmosphereTheme.light()),
        surfaceSize: const Size(390, 844),
      );

      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'screen_profile_light');
    });
  });
}

// Fake DeviceService for testing
class _FakeDeviceService implements DeviceService {
  _FakeDeviceService({required this.devices});
  final List<app_models.Device> devices;

  @override
  Future<List<app_models.Device>> getDevices() async => devices;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake HomeService for testing
class _FakeHomeService implements HomeService {
  _FakeHomeService({required this.homes});
  final List<Home> homes;

  @override
  Future<List<Home>> getHomes() async => homes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
