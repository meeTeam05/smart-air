import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_air/models/command.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/realtime_event.dart';
import 'package:smart_air/models/telemetry.dart';
import 'package:smart_air/screens/devices/device_dashboard_screen.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/realtime_service.dart';
import 'package:smart_air/widgets/atoms/atmosphere_switch.dart';
import 'package:smart_air/widgets/atoms/sensor_tile.dart';

void main() {
  testWidgets('off mode renders placeholder text in every sensor tile', (
    WidgetTester tester,
  ) async {
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
            'mode': 'standby',
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
            ts: DateTime(2026, 5, 12, 8),
            temperature: 23.4,
            humidity: 55.0,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('--'), findsNWidgets(4));
    expect(find.byType(SensorTile), findsNWidgets(4));
  });

  testWidgets('shows loading state while dashboard data is bootstrapping', (
    WidgetTester tester,
  ) async {
    final shadowCompleter = Completer<DeviceShadow>();
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
        'device-1': DeviceShadow(reported: {'mode': 'on'}),
      },
      telemetry: const {'device-1': []},
      shadowCompleter: shadowCompleter,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Loading device dashboard...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    shadowCompleter.complete(const DeviceShadow(reported: {'mode': 'on'}));
    await tester.pumpAndSettle();
  });

  testWidgets('shows error state when dashboard status fails to load', (
    WidgetTester tester,
  ) async {
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
        'device-1': DeviceShadow(reported: {'mode': 'on'}),
      },
      telemetry: const {'device-1': []},
      shadowError: Exception('shadow failed'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to load device dashboard.'), findsOneWidget);
    expect(find.text('Unable to load device status.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('uses latest telemetry values when device is on', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
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
            'temperature': 19.0,
            'humidity': 44.0,
            'co_ppm': 1.0,
            'no2_ppm': 0.1,
          },
        ),
      },
      telemetry: {
        'device-1': [
          TelemetryPoint(
            ts: now,
            temperature: 24.6,
            humidity: 61.2,
            coPpm: 5.4,
            no2Ppm: 0.3,
            mode: 'on',
          ),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('24.60'), findsOneWidget);
    expect(find.text('61.20'), findsOneWidget);
    expect(find.text('5.40'), findsOneWidget);
    expect(find.text('0.30'), findsOneWidget);
  });

  testWidgets('online presence renders without relative time', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeDeviceService(
      devices: [
        Device(
          id: 'device-1',
          name: 'Living Room',
          homeId: 'home-1',
          online: true,
          lastSeen: DateTime(2026, 5, 12, 8),
        ),
      ],
      shadows: const {
        'device-1': DeviceShadow(reported: {'mode': 'on'}),
      },
      telemetry: const {'device-1': []},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('● Online'), findsOneWidget);
    expect(find.textContaining('● Online -'), findsNothing);
  });

  testWidgets('offline presence renders relative time instead of standby', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeDeviceService(
      devices: [
        Device(
          id: 'device-1',
          name: 'Living Room',
          homeId: 'home-1',
          online: false,
          lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ],
      shadows: const {
        'device-1': DeviceShadow(reported: {'mode': 'off'}),
      },
      telemetry: const {'device-1': []},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('● Offline -'), findsOneWidget);
    expect(find.textContaining('STANDBY'), findsNothing);
  });

  testWidgets('settings action opens device settings directly', (
    WidgetTester tester,
  ) async {
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
          reported: {'mode': 'on', 'temperature': 24.0, 'humidity': 55.0},
        ),
      },
      telemetry: const {'device-1': []},
    );
    final router = GoRouter(
      initialLocation: '/devices/device-1',
      routes: [
        GoRoute(
          path: '/devices/:id',
          builder: (_, state) =>
              DeviceDashboardScreen(deviceId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/devices/:id/settings',
          builder: (_, __) => const Scaffold(body: Text('Settings page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Device settings'), findsOneWidget);
    expect(find.text('View charts'), findsNothing);

    await tester.tap(find.byTooltip('Device settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings page'), findsOneWidget);
  });

  testWidgets(
    'updates sensor tile from realtime event without telemetry reload',
    (WidgetTester tester) async {
      final events = StreamController<RealtimeEvent>.broadcast();
      final now = DateTime.now();
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
              'temperature': 19.0,
              'humidity': 44.0,
              'co_ppm': 1.0,
              'no2_ppm': 0.1,
            },
          ),
        },
        telemetry: {
          'device-1': [
            TelemetryPoint(
              ts: now,
              temperature: 24.6,
              humidity: 61.2,
              coPpm: 5.4,
              no2Ppm: 0.3,
              mode: 'on',
            ),
          ],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(fakeService),
            realtimeEventsProvider.overrideWith((ref) => events.stream),
          ],
          child: const MaterialApp(
            home: DeviceDashboardScreen(deviceId: 'device-1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fakeService.telemetryFetchCount, 1);

      events.add(
        RealtimeEvent(
          id: '42',
          type: 'telemetry.point',
          deviceId: 'device-1',
          occurredAt: now.add(const Duration(seconds: 5)),
          payload: {
            'ts': now.add(const Duration(seconds: 5)).toUtc().toIso8601String(),
            'temperature': 26.1,
            'humidity': 62,
            'co_ppm': 6,
            'no2_ppm': 0.4,
            'mode': 'on',
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('26.10'), findsOneWidget);
      expect(find.text('62.00'), findsOneWidget);
      expect(find.text('6.00'), findsOneWidget);
      expect(find.text('0.40'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fakeService.telemetryFetchCount, 1);
      await events.close();
    },
  );

  testWidgets(
    'relay toggle waits for realtime shadow confirmation instead of polling',
    (WidgetTester tester) async {
      final events = StreamController<RealtimeEvent>.broadcast();
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
          'device-1': DeviceShadow(reported: {'mode': 'on', 'relay_1': false}),
        },
        telemetry: const {'device-1': []},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(fakeService),
            realtimeEventsProvider.overrideWith((ref) => events.stream),
          ],
          child: const MaterialApp(
            home: DeviceDashboardScreen(deviceId: 'device-1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final relaySwitch = find.byType(AtmosphereSwitch).at(1);
      await tester.ensureVisible(relaySwitch);
      await tester.tap(relaySwitch, warnIfMissed: false);
      await tester.pump();

      expect(fakeService.waitCalled, isFalse);
      expect(fakeService.relaySetCalls, 1);

      events.add(
        RealtimeEvent(
          id: 'relay-sent',
          type: 'command.updated',
          deviceId: 'device-1',
          occurredAt: DateTime(2026, 5, 12, 8, 0, 1),
          payload: {
            'command_id': 'cmd-1',
            'status': 'sent',
            'payload': {'type': 'relay_set', 'relay': 1, 'state': true},
          },
        ),
      );
      await tester.pump();

      await tester.tap(relaySwitch, warnIfMissed: false);
      await tester.pump();
      expect(fakeService.relaySetCalls, 1);

      events.add(
        RealtimeEvent(
          id: 'relay-shadow',
          type: 'shadow.reported',
          deviceId: 'device-1',
          occurredAt: DateTime(2026, 5, 12, 8, 0, 2),
          payload: {
            'reported': {'mode': 'on', 'relay_1': true},
            'patch': {'relay_1': true},
          },
        ),
      );
      await tester.pump();

      await tester.tap(relaySwitch, warnIfMissed: false);
      await tester.pump();
      expect(fakeService.relaySetCalls, 2);
      expect(fakeService.telemetryFetchCount, 1);
      await events.close();
    },
  );

  testWidgets(
    'shows queued message after relay command stays pending for five seconds',
    (WidgetTester tester) async {
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
          'device-1': DeviceShadow(reported: {'mode': 'on', 'relay_1': false}),
        },
        telemetry: const {'device-1': []},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceServiceProvider.overrideWithValue(fakeService),
            realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: const MaterialApp(
            home: DeviceDashboardScreen(deviceId: 'device-1'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final relaySwitch = find.byType(AtmosphereSwitch).at(1);
      await tester.ensureVisible(relaySwitch);
      await tester.tap(relaySwitch, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(
        find.text('Command queued. It will run when the device reconnects.'),
        findsOneWidget,
      );
      expect(find.textContaining('Failed to toggle relay:'), findsNothing);
      expect(fakeService.waitCalled, isFalse);
    },
  );

  testWidgets('mode toggle also resolves from realtime shadow updates', (
    WidgetTester tester,
  ) async {
    final events = StreamController<RealtimeEvent>.broadcast();
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
        'device-1': DeviceShadow(reported: {'mode': 'off'}),
      },
      telemetry: const {'device-1': []},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => events.stream),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final modeSwitch = find.byType(AtmosphereSwitch).first;
    await tester.tap(modeSwitch, warnIfMissed: false);
    await tester.pump();

    expect(fakeService.modeSetCalls, 1);
    expect(fakeService.waitCalled, isFalse);

    await tester.tap(modeSwitch, warnIfMissed: false);
    await tester.pump();
    expect(fakeService.modeSetCalls, 1);

    events.add(
      RealtimeEvent(
        id: 'mode-shadow',
        type: 'shadow.reported',
        deviceId: 'device-1',
        occurredAt: DateTime(2026, 5, 12, 8, 0, 2),
        payload: {
          'reported': {'mode': 'on'},
          'patch': {'mode': 'on'},
        },
      ),
    );
    await tester.pump();

    expect(find.text('ON'), findsOneWidget);
    await events.close();
  });

  testWidgets('dashboard can unmount while realtime stream is still open', (
    WidgetTester tester,
  ) async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final now = DateTime.now();
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
            'temperature': 19.0,
            'humidity': 44.0,
            'co_ppm': 1.0,
            'no2_ppm': 0.1,
          },
        ),
      },
      telemetry: {
        'device-1': [
          TelemetryPoint(
            ts: now,
            temperature: 24.6,
            humidity: 61.2,
            coPpm: 5.4,
            no2Ppm: 0.3,
            mode: 'on',
          ),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeService),
          realtimeEventsProvider.overrideWith((ref) => events.stream),
        ],
        child: const MaterialApp(
          home: DeviceDashboardScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    events.add(
      RealtimeEvent(
        id: '99',
        type: 'telemetry.point',
        deviceId: 'device-1',
        occurredAt: now.add(const Duration(seconds: 5)),
        payload: {
          'ts': now.add(const Duration(seconds: 5)).toUtc().toIso8601String(),
          'temperature': 26.1,
          'humidity': 62,
          'co_ppm': 6,
          'no2_ppm': 0.4,
          'mode': 'on',
        },
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await events.close();
  });
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({
    required this.devices,
    required this.shadows,
    required this.telemetry,
    this.shadowCompleter,
    this.shadowError,
  }) : super(Dio());

  final List<Device> devices;
  final Map<String, DeviceShadow> shadows;
  final Map<String, List<TelemetryPoint>> telemetry;
  final Completer<DeviceShadow>? shadowCompleter;
  final Object? shadowError;
  final List<Command> commands = [];
  int telemetryFetchCount = 0;
  int relaySetCalls = 0;
  int modeSetCalls = 0;
  bool relay1On = false;
  bool waitCalled = false;
  bool shadowRefreshedBeforeWait = false;
  bool actionStarted = false;

  @override
  Future<List<Device>> getDevices() async => devices;

  @override
  Future<DeviceShadow> getShadow(String deviceId) async {
    if (shadowCompleter != null) {
      return shadowCompleter!.future;
    }
    if (shadowError != null) {
      throw shadowError!;
    }
    if (actionStarted && !waitCalled) {
      shadowRefreshedBeforeWait = true;
    }
    final shadow = shadows[deviceId];
    if (shadow == null) return const DeviceShadow();

    final reported = Map<String, dynamic>.from(shadow.reported);
    if (waitCalled) {
      reported['relay_1'] = relay1On;
    }
    return DeviceShadow(reported: reported, desired: shadow.desired);
  }

  @override
  Future<List<TelemetryPoint>> getTelemetry(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    String? agg,
    int limit = 1000,
  }) async {
    telemetryFetchCount += 1;
    return telemetry[deviceId] ?? const [];
  }

  @override
  Future<void> setDesired(
    String deviceId,
    Map<String, dynamic> desired,
  ) async {}

  @override
  Future<String> setMode(String deviceId, String mode) async {
    modeSetCalls += 1;
    commands.clear();
    commands.add(
      Command(
        id: 'mode-cmd-1',
        payload: {'type': 'device_mode', 'mode': mode},
        status: 'pending',
        createdAt: DateTime(2026, 5, 12, 8),
      ),
    );
    return 'mode-cmd-1';
  }

  @override
  Future<String> setRelay(String deviceId, int channel, bool state) async {
    relaySetCalls += 1;
    actionStarted = true;
    relay1On = state;
    commands.clear();
    commands.add(
      Command(
        id: 'cmd-1',
        payload: {'type': 'relay_set', 'relay': channel, 'state': state},
        status: 'pending',
        createdAt: DateTime(2026, 5, 12, 8),
      ),
    );
    return 'cmd-1';
  }

  @override
  Future<Command> waitForCommandCompletion(
    String deviceId,
    String commandId, {
    Duration timeout = const Duration(minutes: 3),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    waitCalled = true;
    commands
      ..clear()
      ..add(
        Command(
          id: commandId,
          payload: {'type': 'relay_set', 'relay': 1, 'state': relay1On},
          status: 'done',
          createdAt: DateTime(2026, 5, 12, 8),
          executedAt: DateTime(2026, 5, 12, 8, 0, 1),
        ),
      );
    return commands.single;
  }

  @override
  Future<List<Command>> getCommands(
    String deviceId, {
    int limit = 50,
    int offset = 0,
  }) async => commands;
}
