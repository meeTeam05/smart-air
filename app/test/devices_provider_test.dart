import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/realtime_event.dart';
import 'package:smart_air/providers/devices_provider.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  test('devicesProvider applies shadow.reported updates to device summaries',
      () async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final fakeService = _FakeDeviceService(
      devices: const [
        Device(
          id: 'device-1',
          name: 'Living Room',
          homeId: 'home-1',
          online: true,
          mode: 'off',
          relay1: false,
          relay2: false,
          relay3: false,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(fakeService),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    final subscription = container.listen(
      devicesProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final initial = await container.read(devicesProvider.future);
    expect(initial.single.mode, 'off');
    expect(initial.single.relay1, isFalse);

    events.add(
      RealtimeEvent(
        id: '42',
        type: 'shadow.reported',
        deviceId: 'device-1',
        occurredAt: DateTime.now(),
        payload: const {
          'reported': {
            'mode': 'on',
            'relay_1': true,
          },
          'patch': {
            'mode': 'on',
            'relay_1': true,
          },
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final live = container.read(devicesProvider).value!;
    expect(live.single.mode, 'on');
    expect(live.single.relay1, isTrue);
    expect(live.single.relay2, isFalse);
  });

  test('devicesProvider refetches device summaries after replay.reset',
      () async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final fakeService = _FakeDeviceService(
      deviceSnapshots: [
        const [
          Device(
            id: 'device-1',
            name: 'Living Room',
            homeId: 'home-1',
            online: true,
          ),
        ],
        [
          Device(
            id: 'device-1',
            name: 'Living Room',
            homeId: 'home-1',
            online: false,
            lastSeen: DateTime(2026, 5, 15, 8, 30),
          ),
        ],
      ],
    );
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(fakeService),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    final subscription = container.listen(
      devicesProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final initial = await container.read(devicesProvider.future);
    expect(initial.single.online, isTrue);
    expect(fakeService.getDevicesCallCount, 1);

    events.add(
      RealtimeEvent(
        id: 'reset-1',
        type: 'replay.reset',
        deviceId: '',
        occurredAt: DateTime(2026, 5, 15, 8, 31),
        payload: const {'reason': 'replay_unavailable'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final refreshed = container.read(devicesProvider).value!;
    expect(fakeService.getDevicesCallCount, 2);
    expect(refreshed.single.online, isFalse);
    expect(refreshed.single.lastSeen, DateTime(2026, 5, 15, 8, 30));
  });
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({
    List<Device> devices = const [],
    List<List<Device>>? deviceSnapshots,
  })  : _deviceSnapshots = deviceSnapshots ?? [devices],
        super(Dio());

  final List<List<Device>> _deviceSnapshots;
  int getDevicesCallCount = 0;

  @override
  Future<List<Device>> getDevices() async {
    final index = getDevicesCallCount < _deviceSnapshots.length
        ? getDevicesCallCount
        : _deviceSnapshots.length - 1;
    getDevicesCallCount += 1;
    return _deviceSnapshots[index];
  }
}
