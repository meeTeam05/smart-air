import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_air/core/api_client.dart';
import 'package:smart_air/core/secure_storage.dart';
import 'package:smart_air/design/icons.dart';
import 'package:smart_air/models/command.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/models/telemetry.dart';
import 'package:smart_air/screens/devices/command_history_screen.dart';
import 'package:smart_air/screens/devices/device_dashboard_screen.dart';
import 'package:smart_air/screens/devices/settings/calibration_wizard_screen.dart';
import 'package:smart_air/screens/devices/settings/general_screen.dart';
import 'package:smart_air/screens/devices/settings/ota_screen.dart';
import 'package:smart_air/screens/profile/home_detail_screen.dart';
import 'package:smart_air/screens/provision/step5_name.dart';
import 'package:smart_air/services/auth_service.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  testWidgets('provisioning success opens dashboard and back returns home',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialLocation: '/provision/name',
        routes: _deviceRoutes(
          homePushesDevice: false,
          includeProvisionName: true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Name your device'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceDashboardScreen), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();

    expect(find.text('Home root'), findsOneWidget);
  });

  testWidgets('direct dashboard entry falls back to home on system back',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialLocation: '/devices/device-1',
        routes: _deviceRoutes(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(DeviceDashboardScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Home root'), findsOneWidget);
  });

  testWidgets('stacked dashboard entry still pops to previous home route',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialLocation: '/home',
        routes: _deviceRoutes(homePushesDevice: true),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Open device'), findsOneWidget);

    await tester.tap(find.text('Open device'));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceDashboardScreen), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();

    expect(find.text('Open device'), findsOneWidget);
    expect(find.byType(DeviceDashboardScreen), findsNothing);
  });

  testWidgets('device drill-down routes fall back to expected parents',
      (tester) async {
    Future<void> verifyFallback(
      String initialLocation,
      String expectedText,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialLocation: initialLocation,
          routes: _deviceRoutes(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.back));
      await tester.pumpAndSettle();
      expect(find.text(expectedText), findsOneWidget);
    }

    await verifyFallback('/devices/device-1/settings', 'Living Room');
    await verifyFallback('/devices/device-1/commands', 'Living Room');
    await verifyFallback('/devices/device-1/ota', 'Settings');
    await verifyFallback('/devices/device-1/calibrate/co', 'Settings');
  });

  testWidgets('home detail route falls back to homes list', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialLocation: '/homes/home-1',
        routes: _homeDetailRoutes(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();

    expect(find.text('Homes root'), findsOneWidget);
  });

  testWidgets('profile home detail route falls back to profile root',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialLocation: '/profile/home/home-1',
        routes: _homeDetailRoutes(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();

    expect(find.text('Profile root'), findsOneWidget);
  });
}

Widget _buildTestApp({
  required String initialLocation,
  required List<RouteBase> routes,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: routes,
  );

  return ProviderScope(
    overrides: [
      deviceServiceProvider.overrideWithValue(_FakeDeviceService()),
      homeServiceProvider.overrideWithValue(_FakeHomeService()),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

List<RouteBase> _deviceRoutes({
  bool homePushesDevice = false,
  bool includeProvisionName = false,
}) {
  return [
    GoRoute(
      path: '/home',
      builder: (context, _) => Scaffold(
        body: Center(
          child: homePushesDevice
              ? FilledButton(
                  onPressed: () =>
                      GoRouter.of(context).push('/devices/device-1'),
                  child: const Text('Open device'),
                )
              : const Text('Home root'),
        ),
      ),
    ),
    if (includeProvisionName)
      GoRoute(
        path: '/provision/name',
        builder: (_, __) => const Step5NameScreen(
          homeId: 'home-1',
          mac: 'dc:b4:d9:13:ed:8c',
          deviceId: 'device-1',
        ),
      ),
    GoRoute(
      path: '/devices/:id',
      builder: (_, state) =>
          DeviceDashboardScreen(deviceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/devices/:id/settings',
      builder: (_, state) =>
          GeneralSettingsScreen(deviceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/devices/:id/commands',
      builder: (_, state) =>
          CommandHistoryScreen(deviceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/devices/:id/ota',
      builder: (_, state) => OtaScreen(deviceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/devices/:id/calibrate/:sensor',
      builder: (_, state) => CalibrationWizardScreen(
        deviceId: state.pathParameters['id']!,
        sensor: state.pathParameters['sensor']!,
      ),
    ),
  ];
}

List<RouteBase> _homeDetailRoutes() {
  return [
    GoRoute(
      path: '/homes',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Homes root')),
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Profile root')),
      ),
    ),
    GoRoute(
      path: '/homes/:homeId',
      builder: (_, state) => HomeDetailScreen(
        homeId: state.pathParameters['homeId']!,
        fallbackRoute: '/homes',
      ),
    ),
    GoRoute(
      path: '/profile/home/:homeId',
      builder: (_, state) => HomeDetailScreen(
        homeId: state.pathParameters['homeId']!,
        fallbackRoute: '/profile',
      ),
    ),
  ];
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService() : super(Dio());

  Device _device = const Device(
    id: 'device-1',
    name: 'Living Room',
    homeId: 'home-1',
    online: true,
    mode: 'on',
    relay1: false,
    relay2: false,
    relay3: false,
    firmwareVer: '1.0.0',
  );

  @override
  Future<List<Device>> getDevices() async => [_device];

  @override
  Future<DeviceShadow> getShadow(String deviceId) async => const DeviceShadow(
        reported: {
          'mode': 'on',
          'relay_1': false,
          'relay_2': false,
          'relay_3': false,
          'temperature': 24.5,
          'humidity': 55.0,
          'co_ppm': 4.0,
          'no2_ppm': 0.3,
        },
      );

  @override
  Future<List<TelemetryPoint>> getTelemetry(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    String? agg,
    int limit = 1000,
  }) async =>
      const [];

  @override
  Future<List<Command>> getCommands(
    String deviceId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      const [];

  @override
  Future<Device> updateDevice(String id, {String? name, String? roomId}) async {
    _device = _device.copyWith(
      name: name ?? _device.name,
      roomId: roomId,
    );
    return _device;
  }
}

class _FakeHomeService extends HomeService {
  _FakeHomeService() : super(Dio());

  @override
  Future<List<Home>> getHomes() async => const [
        Home(id: 'home-1', name: 'My Home', ownerId: 'user-1'),
      ];

  @override
  Future<List<Room>> getRooms(String homeId) async => const [
        Room(id: 'room-1', homeId: 'home-1', name: 'Living Room'),
      ];
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(Dio());

  @override
  Future<void> logout() async {}
}

class _FakeSecureStorage extends SecureStorage {
  @override
  Future<String?> getRefreshToken() async => 'refresh-token';

  @override
  Future<Map<String, dynamic>?> getUserJson() async => const {
        'id': 'user-1',
        'email': 'test@example.com',
        'full_name': 'Test User',
      };
}
