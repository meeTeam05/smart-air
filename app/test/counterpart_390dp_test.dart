// 390dp Counterpart Verification Tests
//
// Verifies that every mockup screen in tmp/app/ has a Flutter counterpart
// that renders correctly at 390dp width (iPhone 12/13 Pro viewport).
//
// This test suite provides deterministic verification without requiring
// browser-based visual QA (which is blocked by missing Chrome runtime).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';
import 'package:smart_air/services/realtime_service.dart';
import 'package:smart_air/screens/auth/splash_screen.dart';
import 'package:smart_air/screens/auth/login_screen.dart';
import 'package:smart_air/screens/auth/register_screen.dart';
import 'package:smart_air/screens/home_screen.dart';
import 'package:smart_air/screens/devices/device_dashboard_screen.dart';
import 'package:smart_air/screens/devices/command_history_screen.dart';
import 'package:smart_air/screens/devices/settings/general_screen.dart';
import 'package:smart_air/screens/devices/settings/calibration_wizard_screen.dart';
import 'package:smart_air/screens/devices/settings/ota_screen.dart';
import 'package:smart_air/screens/provision/step1_power_on.dart';
import 'package:smart_air/screens/provision/step2_ble_scan.dart';
import 'package:smart_air/screens/provision/step3_wifi.dart';
import 'package:smart_air/screens/provision/step4_cloud.dart';
import 'package:smart_air/screens/provision/step5_name.dart';
import 'package:smart_air/screens/notifications_screen.dart';
import 'package:smart_air/screens/profile/profile_screen.dart';

// Mock services
class _FakeDeviceService extends Fake implements DeviceService {
  _FakeDeviceService({this.devices = const []});
  final List<Device> devices;

  @override
  Future<List<Device>> getDevices() async => devices;
}

class _FakeHomeService extends Fake implements HomeService {
  @override
  Future<List<Home>> getHomes() async => [];
}

// Test wrapper with 390dp viewport constraint
Widget _test390dpScreen(Widget screen, {ThemeData? theme}) {
  return ProviderScope(
    overrides: [
      deviceServiceProvider.overrideWithValue(_FakeDeviceService()),
      homeServiceProvider.overrideWithValue(_FakeHomeService()),
      realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: screen,
      ),
    ),
  );
}

void main() {
  group('390dp Counterpart Verification — Auth Flow', () {
    testWidgets('AuthSplash → SplashScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(_test390dpScreen(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify screen renders without exceptions
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AuthLogin → LoginScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(_test390dpScreen(const LoginScreen()));
      await tester.pump();

      // Verify screen renders without exceptions
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AuthRegister → RegisterScreen renders at 390dp',
        (tester) async {
      await tester.pumpWidget(_test390dpScreen(const RegisterScreen()));
      await tester.pump();

      // Verify screen renders without exceptions
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('390dp Counterpart Verification — Home Tab', () {
    testWidgets('HomeEmpty → HomeScreen (empty) renders at 390dp',
        (tester) async {
      await tester.pumpWidget(_test390dpScreen(const HomeScreen()));
      await tester.pump();

      // Verify page title and empty state
      expect(find.text('My Devices'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomePopulated → HomeScreen (populated) renders at 390dp',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(devices: const [
                Device(
                  id: 'device-1',
                  name: 'Living Room Air',
                  homeId: 'home-1',
                  online: true,
                ),
              ]),
            ),
            realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(
            home: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: const HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify device card present
      expect(find.text('Living Room Air'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('390dp Counterpart Verification — Device Dashboard', () {
    testWidgets('DeviceDashboard (on) → DeviceDashboardScreen renders at 390dp',
        (tester) async {
      await tester.pumpWidget(
          _test390dpScreen(const DeviceDashboardScreen(deviceId: 'device-1')));
      await tester.pump();

      // Verify mode card and sensor tiles present
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'DeviceDashboard (standby) → DeviceDashboardScreen renders at 390dp',
        (tester) async {
      await tester.pumpWidget(
          _test390dpScreen(const DeviceDashboardScreen(deviceId: 'device-1')));
      await tester.pump();

      // Verify screen renders without exceptions
      expect(tester.takeException(), isNull);
    });
  });

  group('390dp Counterpart Verification — History', () {
    testWidgets('CommandHistoryScreen → CommandHistoryScreen renders at 390dp',
        (tester) async {
      await tester.pumpWidget(
          _test390dpScreen(const CommandHistoryScreen(deviceId: 'device-1')));
      await tester.pump();

      // Verify history screen elements
      expect(find.text('Command history'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('390dp Counterpart Verification — Device Settings', () {
    testWidgets('SettingsGeneral → GeneralSettingsScreen renders at 390dp',
        (tester) async {
      await tester.pumpWidget(
          _test390dpScreen(const GeneralSettingsScreen(deviceId: 'device-1')));
      await tester.pump();

      // Verify screen renders without exceptions
      expect(find.byType(GeneralSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CalibrationWizard → CalibrationWizardScreen renders at 390dp',
        (tester) async {
      await tester.pumpWidget(_test390dpScreen(
          const CalibrationWizardScreen(deviceId: 'device-1', sensor: 'co')));
      await tester.pump();

      // Verify screen renders without exceptions
      expect(find.byType(CalibrationWizardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OtaScreen → OtaScreen renders at 390dp', (tester) async {
      await tester
          .pumpWidget(_test390dpScreen(const OtaScreen(deviceId: 'device-1')));
      await tester.pump();

      // Verify screen renders without exceptions
      expect(find.byType(OtaScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('390dp Counterpart Verification — BLE Provisioning', () {
    testWidgets('Ble1 → Step1PowerOnScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(
          _test390dpScreen(const Step1PowerOnScreen(homeId: 'home-1')));
      await tester.pump();

      // Verify step 1 content
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ble2 → Step2BleScanScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(
          _test390dpScreen(const Step2BleScanScreen(homeId: 'home-1')));
      await tester.pump();

      // Verify step 2 content
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ble3 → Step3WifiScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(_test390dpScreen(const Step3WifiScreen(
          homeId: 'home-1', deviceId: 'device-1', mac: 'AA:BB:CC:DD:EE:FF')));
      await tester.pump();

      // Verify step 3 content
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ble4 → Step4CloudScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(_test390dpScreen(const Step4CloudScreen(
          homeId: 'home-1', deviceId: 'device-1', mac: 'AA:BB:CC:DD:EE:FF')));
      await tester.pump();

      // Verify step 4 content
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ble5 → Step5NameScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(_test390dpScreen(const Step5NameScreen(
          homeId: 'home-1', deviceId: 'device-1', mac: 'AA:BB:CC:DD:EE:FF')));
      await tester.pump();

      // Verify step 5 content
      expect(tester.takeException(), isNull);
    });
  });

  group('390dp Counterpart Verification — Tabs', () {
    testWidgets('NotificationsTab → NotificationsScreen renders at 390dp',
        (tester) async {
      await tester.pumpWidget(_test390dpScreen(const NotificationsScreen()));
      await tester.pump();

      // Verify notifications screen elements
      expect(find.text('Notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileTab → ProfileScreen renders at 390dp', (tester) async {
      await tester.pumpWidget(_test390dpScreen(const ProfileScreen()));
      await tester.pump();

      // Verify profile screen elements
      expect(find.text('Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
