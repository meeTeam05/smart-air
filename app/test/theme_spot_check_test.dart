import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/models/telemetry.dart';
import 'package:smart_air/models/user.dart';
import 'package:smart_air/screens/auth/login_screen.dart';
import 'package:smart_air/screens/home_screen.dart';
import 'package:smart_air/screens/devices/device_dashboard_screen.dart';
import 'package:smart_air/screens/devices/device_chart_screen.dart';
import 'package:smart_air/screens/profile/profile_screen.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';
import 'package:smart_air/services/realtime_service.dart';
import 'package:smart_air/providers/auth_provider.dart';

/// Theme spot-check tests for hero screens.
/// Verifies that each screen renders without exceptions in both light and dark themes.
void main() {
  group('Login Screen', () {
    testWidgets('renders in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home Screen', () {
    testWidgets('renders in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(devices: const [
                Device(
                  id: 'device-1',
                  name: 'Living Room',
                  homeId: 'home-1',
                  online: true,
                ),
              ]),
            ),
            realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(devices: const [
                Device(
                  id: 'device-1',
                  name: 'Living Room',
                  homeId: 'home-1',
                  online: true,
                ),
              ]),
            ),
            realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Device Dashboard', () {
    testWidgets('renders in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(
                devices: const [
                  Device(
                    id: 'device-1',
                    name: 'Living Room',
                    homeId: 'home-1',
                    online: true,
                  ),
                ],
                shadows: const {
                  'device-1': DeviceShadow(
                    reported: {
                      'mode': 'on',
                      'temperature': 23.4,
                      'humidity': 55.0,
                    },
                  ),
                },
                telemetry: const {},
              ),
            ),
            realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const DeviceDashboardScreen(deviceId: 'device-1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DeviceDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(
                devices: const [
                  Device(
                    id: 'device-1',
                    name: 'Living Room',
                    homeId: 'home-1',
                    online: true,
                  ),
                ],
                shadows: const {
                  'device-1': DeviceShadow(
                    reported: {
                      'mode': 'on',
                      'temperature': 23.4,
                      'humidity': 55.0,
                    },
                  ),
                },
                telemetry: const {},
              ),
            ),
            realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const DeviceDashboardScreen(deviceId: 'device-1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DeviceDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Charts Screen', () {
    testWidgets('renders in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(
                devices: const [
                  Device(
                    id: 'device-1',
                    name: 'Living Room',
                    homeId: 'home-1',
                    online: true,
                  ),
                ],
                telemetry: {
                  'device-1': [
                    TelemetryPoint(
                      ts: DateTime(2026, 5, 11, 8),
                      temperature: 23.4,
                      humidity: 55.0,
                    ),
                  ],
                },
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const DeviceChartScreen(deviceId: 'device-1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DeviceChartScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(
              _FakeDeviceService(
                devices: const [
                  Device(
                    id: 'device-1',
                    name: 'Living Room',
                    homeId: 'home-1',
                    online: true,
                  ),
                ],
                telemetry: {
                  'device-1': [
                    TelemetryPoint(
                      ts: DateTime(2026, 5, 11, 8),
                      temperature: 23.4,
                      humidity: 55.0,
                    ),
                  ],
                },
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const DeviceChartScreen(deviceId: 'device-1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DeviceChartScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Profile Screen', () {
    testWidgets('renders in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_FakeAuthNotifier.new),
            homeServiceProvider.overrideWithValue(_FakeHomeService()),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_FakeAuthNotifier.new),
            homeServiceProvider.overrideWithValue(_FakeHomeService()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// Fake services for testing

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({
    required this.devices,
    this.shadows = const {},
    this.telemetry = const {},
  }) : super(Dio());

  final List<Device> devices;
  final Map<String, DeviceShadow> shadows;
  final Map<String, List<TelemetryPoint>> telemetry;

  @override
  Future<List<Device>> getDevices() async => devices;

  @override
  Future<DeviceShadow> getShadow(String deviceId) async =>
      shadows[deviceId] ?? const DeviceShadow();

  @override
  Future<List<TelemetryPoint>> getTelemetry(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    String? agg,
    int limit = 1000,
  }) async =>
      telemetry[deviceId] ?? const [];

  @override
  Future<void> setDesired(
      String deviceId, Map<String, dynamic> desired) async {}
}

class _FakeHomeService extends HomeService {
  _FakeHomeService() : super(Dio());

  @override
  Future<List<Home>> getHomes() async => const [];
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    return const User(
      id: 'user-1',
      email: 'test@example.com',
      fullName: 'Test User',
    );
  }
}
