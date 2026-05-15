import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/realtime_event.dart';
import 'package:smart_air/models/telemetry.dart';
import 'package:smart_air/providers/devices_provider.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  test('telemetryLiveProvider appends realtime points without reloading',
      () async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final now = DateTime.now();
    final nextTs = now.add(const Duration(seconds: 5));
    final fakeService = _FakeDeviceService(
      telemetry: [
        TelemetryPoint(
          ts: now,
          temperature: 24,
          humidity: 60,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(fakeService),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
        realtimeConnectionStatusProvider
            .overrideWith((ref) => RealtimeStatus.connected),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    final subscription = container.listen(
      telemetryLiveProvider('device-1'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final initial =
        await container.read(telemetryLiveProvider('device-1').future);
    expect(initial.points, hasLength(1));
    expect(initial.latest?.temperature, 24);
    expect(fakeService.fetchCount, 1);

    events.add(
      RealtimeEvent(
        id: '42',
        type: 'telemetry.point',
        deviceId: 'device-1',
        occurredAt: nextTs,
        payload: {
          'ts': nextTs.toUtc().toIso8601String(),
          'temperature': 25.5,
          'humidity': 61.2,
          'mode': 'on',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final live = container.read(telemetryLiveProvider('device-1')).value!;
    expect(live.points, hasLength(2));
    expect(live.latest?.temperature, 25.5);
    expect(live.refreshing, isFalse);
    expect(fakeService.fetchCount, 1);
  });

  test('telemetryLiveProvider dedupes realtime points by timestamp', () async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final now = DateTime.now();
    final fakeService = _FakeDeviceService(
      telemetry: [
        TelemetryPoint(
          ts: now,
          temperature: 24,
          humidity: 60,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(fakeService),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
        realtimeConnectionStatusProvider
            .overrideWith((ref) => RealtimeStatus.connected),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    final subscription = container.listen(
      telemetryLiveProvider('device-1'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(telemetryLiveProvider('device-1').future);
    events.add(
      RealtimeEvent(
        id: '42',
        type: 'telemetry.point',
        deviceId: 'device-1',
        occurredAt: now,
        payload: {
          'ts': now.toUtc().toIso8601String(),
          'temperature': 25.5,
          'humidity': 61.2,
          'mode': 'on',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final live = container.read(telemetryLiveProvider('device-1')).value!;
    expect(live.points, hasLength(1));
    expect(live.latest?.temperature, 25.5);
    expect(fakeService.fetchCount, 1);
  });

  test('telemetryLiveProvider refreshes snapshot after replay reset', () async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final now = DateTime.now();
    final fakeService = _FakeDeviceService(
      telemetry: [
        TelemetryPoint(
          ts: now,
          temperature: 24,
          humidity: 60,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(fakeService),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
        realtimeConnectionStatusProvider
            .overrideWith((ref) => RealtimeStatus.connected),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    final subscription = container.listen(
      telemetryLiveProvider('device-1'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(telemetryLiveProvider('device-1').future);
    fakeService.telemetry
      ..clear()
      ..add(
        TelemetryPoint(
          ts: now.add(const Duration(seconds: 5)),
          temperature: 26,
          humidity: 62,
        ),
      );
    events.add(
      RealtimeEvent(
        id: '43',
        type: 'replay.reset',
        deviceId: '',
        occurredAt: now,
        payload: const {'reason': 'replay_unavailable'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final live = container.read(telemetryLiveProvider('device-1')).value!;
    expect(fakeService.fetchCount, 2);
    expect(live.latest?.temperature, 26);
  });

  test('telemetryLiveProvider disposes after last listener is removed',
      () async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final now = DateTime.now();
    final fakeService = _FakeDeviceService(
      telemetry: [
        TelemetryPoint(
          ts: now,
          temperature: 24,
          humidity: 60,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(fakeService),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
        realtimeConnectionStatusProvider
            .overrideWith((ref) => RealtimeStatus.connected),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    final subscription = container.listen(
      telemetryLiveProvider('device-1'),
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(telemetryLiveProvider('device-1').future);

    expect(container.exists(telemetryLiveProvider('device-1')), isTrue);

    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.exists(telemetryLiveProvider('device-1')), isFalse);

    events.add(
      RealtimeEvent(
        id: '44',
        type: 'telemetry.point',
        deviceId: 'device-1',
        occurredAt: now.add(const Duration(seconds: 10)),
        payload: {
          'ts': now.add(const Duration(seconds: 10)).toUtc().toIso8601String(),
          'temperature': 27,
          'humidity': 64,
          'mode': 'on',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.exists(telemetryLiveProvider('device-1')), isFalse);
  });
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({required this.telemetry}) : super(Dio());

  final List<TelemetryPoint> telemetry;
  int fetchCount = 0;

  @override
  Future<List<TelemetryPoint>> getTelemetry(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    String? agg,
    int limit = 1000,
  }) async {
    fetchCount += 1;
    return telemetry;
  }
}
