import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/api_client.dart';
import 'package:smart_air/core/router.dart';
import 'package:smart_air/core/secure_storage.dart';
import 'package:smart_air/main.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/models/realtime_event.dart';
import 'package:smart_air/models/telemetry.dart';
import 'package:smart_air/providers/auth_provider.dart';
import 'package:smart_air/screens/home_screen.dart';
import 'package:smart_air/screens/devices/device_dashboard_screen.dart';
import 'package:smart_air/services/auth_service.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  testWidgets('logout tears down live dashboard without inherited assertion',
      (WidgetTester tester) async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final storage = _FakeSecureStorage();
    final fakeService = _FakeDeviceService(
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
            'co_ppm': 4.2,
            'no2_ppm': 0.8,
          },
        ),
      },
      telemetry: {
        'device-1': [
          TelemetryPoint(
            ts: DateTime(2026, 5, 15, 8),
            temperature: 23.4,
            humidity: 55.0,
            coPpm: 4.2,
            no2Ppm: 0.8,
            mode: 'on',
          ),
        ],
      },
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        secureStorageProvider.overrideWithValue(storage),
        deviceServiceProvider.overrideWithValue(fakeService),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final auth = ref.watch(authProvider);
              if (auth.isLoading) {
                return const SizedBox.shrink();
              }
              return auth.valueOrNull == null
                  ? const SizedBox(key: Key('logged-out'))
                  : const DeviceDashboardScreen(deviceId: 'device-1');
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DeviceDashboardScreen), findsOneWidget);

    await container.read(authProvider.notifier).logout();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    events.add(
      RealtimeEvent(
        id: 'logout-1',
        type: 'telemetry.point',
        deviceId: 'device-1',
        occurredAt: DateTime(2026, 5, 15, 8, 0, 5),
        payload: const {
          'ts': '2026-05-15T01:00:05.000Z',
          'temperature': 24.1,
          'humidity': 54.1,
          'co_ppm': 4.7,
          'no2_ppm': 0.9,
          'mode': 'on',
        },
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('logged-out')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('router can pop live dashboard without inherited assertion',
      (WidgetTester tester) async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        homeServiceProvider.overrideWithValue(_FakeHomeService()),
        deviceServiceProvider.overrideWithValue(
          _FakeDeviceService(
            devices: const [
              Device(
                id: 'device-1',
                name: 'Living Room',
                homeId: 'home-1',
                roomId: 'room-1',
                online: true,
              ),
            ],
            shadows: const {
              'device-1': DeviceShadow(
                reported: {
                  'mode': 'on',
                  'temperature': 23.4,
                  'humidity': 55.0,
                  'co_ppm': 4.2,
                  'no2_ppm': 0.8,
                },
              ),
            },
            telemetry: {
              'device-1': [
                TelemetryPoint(
                  ts: DateTime(2026, 5, 15, 8),
                  temperature: 23.4,
                  humidity: 55.0,
                  coPpm: 4.2,
                  no2Ppm: 0.8,
                  mode: 'on',
                ),
              ],
            },
          ),
        ),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SmartAirApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    unawaited(container.read(routerProvider).push('/devices/device-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DeviceDashboardScreen), findsOneWidget);

    container.read(routerProvider).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    events.add(
      RealtimeEvent(
        id: 'route-1',
        type: 'telemetry.point',
        deviceId: 'device-1',
        occurredAt: DateTime(2026, 5, 15, 8, 0, 5),
        payload: const {
          'ts': '2026-05-15T01:00:05.000Z',
          'temperature': 24.1,
          'humidity': 54.1,
          'co_ppm': 4.7,
          'no2_ppm': 0.9,
          'mode': 'on',
        },
      ),
    );
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('router logout can redirect away from live dashboard safely',
      (WidgetTester tester) async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        homeServiceProvider.overrideWithValue(_FakeHomeService()),
        deviceServiceProvider.overrideWithValue(
          _FakeDeviceService(
            devices: const [
              Device(
                id: 'device-1',
                name: 'Living Room',
                homeId: 'home-1',
                roomId: 'room-1',
                online: true,
              ),
            ],
            shadows: const {
              'device-1': DeviceShadow(
                reported: {
                  'mode': 'on',
                  'temperature': 23.4,
                  'humidity': 55.0,
                  'co_ppm': 4.2,
                  'no2_ppm': 0.8,
                },
              ),
            },
            telemetry: {
              'device-1': [
                TelemetryPoint(
                  ts: DateTime(2026, 5, 15, 8),
                  temperature: 23.4,
                  humidity: 55.0,
                  coPpm: 4.2,
                  no2Ppm: 0.8,
                  mode: 'on',
                ),
              ],
            },
          ),
        ),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SmartAirApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    unawaited(container.read(routerProvider).push('/devices/device-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DeviceDashboardScreen), findsOneWidget);

    await container.read(authProvider.notifier).logout();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    events.add(
      RealtimeEvent(
        id: 'route-logout-1',
        type: 'telemetry.point',
        deviceId: 'device-1',
        occurredAt: DateTime(2026, 5, 15, 8, 0, 5),
        payload: const {
          'ts': '2026-05-15T01:00:05.000Z',
          'temperature': 24.1,
          'humidity': 54.1,
          'co_ppm': 4.7,
          'no2_ppm': 0.9,
          'mode': 'on',
        },
      ),
    );
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(Dio());

  @override
  Future<void> logout() async {}
}

class _FakeSecureStorage extends SecureStorage {
  Map<String, dynamic>? _user = const {
    'id': 'user-1',
    'email': 'test@example.com',
    'full_name': 'Test User',
  };
  String? _refreshToken = 'refresh-token';

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<Map<String, dynamic>?> getUserJson() async => _user;

  @override
  Future<void> clear() async {
    _refreshToken = null;
    _user = null;
  }
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({
    required this.devices,
    required this.shadows,
    required this.telemetry,
  }) : super(Dio());

  final List<Device> devices;
  final Map<String, DeviceShadow> shadows;
  final Map<String, List<TelemetryPoint>> telemetry;

  @override
  Future<List<Device>> getDevices() async => devices;

  @override
  Future<DeviceShadow> getShadow(String deviceId) async {
    return shadows[deviceId] ?? const DeviceShadow();
  }

  @override
  Future<List<TelemetryPoint>> getTelemetry(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    String? agg,
    int limit = 1000,
  }) async {
    return telemetry[deviceId] ?? const [];
  }
}

class _FakeHomeService extends HomeService {
  _FakeHomeService() : super(Dio());

  @override
  Future<List<Home>> getHomes() async => const [
        Home(id: 'home-1', name: 'My Home'),
      ];

  @override
  Future<List<Room>> getRooms(String homeId) async => const [
        Room(id: 'room-1', homeId: 'home-1', name: 'Living Room'),
      ];
}
