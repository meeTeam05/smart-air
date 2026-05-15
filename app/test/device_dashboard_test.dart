import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('off mode renders em dash in every sensor tile', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeDeviceService(
      devices: const [
        Device(
            id: 'device-1',
            name: 'Living Room',
            homeId: 'home-1',
            online: true),
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

    expect(find.text('—'), findsNWidgets(4));
    expect(find.byType(SensorTile), findsNWidgets(4));
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

    expect(find.text('24.6'), findsOneWidget);
    expect(find.text('61.2'), findsOneWidget);
    expect(find.text('5.4'), findsOneWidget);
    expect(find.text('0.3'), findsOneWidget);
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

    expect(find.text('26.1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(fakeService.telemetryFetchCount, 1);
    await events.close();
  });

  testWidgets('waits for relay command completion before refreshing shadow', (
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
            'mode': 'on',
            'relay_1': false,
          },
        ),
      },
      telemetry: const {
        'device-1': [],
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
    final relaySwitch = find.byType(AtmosphereSwitch).at(1);
    await tester.ensureVisible(relaySwitch);
    await tester.tap(relaySwitch, warnIfMissed: false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeService.waitCalled, isTrue);
    expect(fakeService.shadowRefreshedBeforeWait, isFalse);
    expect(fakeService.telemetryFetchCount, 1);
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
  }) : super(Dio());

  final List<Device> devices;
  final Map<String, DeviceShadow> shadows;
  final Map<String, List<TelemetryPoint>> telemetry;
  final List<Command> commands = [];
  int telemetryFetchCount = 0;
  bool relay1On = false;
  bool waitCalled = false;
  bool shadowRefreshedBeforeWait = false;
  bool actionStarted = false;

  @override
  Future<List<Device>> getDevices() async => devices;

  @override
  Future<DeviceShadow> getShadow(String deviceId) async {
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
      String deviceId, Map<String, dynamic> desired) async {}

  @override
  Future<String> setRelay(String deviceId, int channel, bool state) async {
    actionStarted = true;
    relay1On = state;
    commands.clear();
    commands.add(
      Command(
        id: 'cmd-1',
        payload: {
          'type': 'relay_set',
          'relay': channel,
          'state': state,
        },
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
          payload: {
            'type': 'relay_set',
            'relay': 1,
            'state': relay1On,
          },
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
  }) async =>
      commands;
}
