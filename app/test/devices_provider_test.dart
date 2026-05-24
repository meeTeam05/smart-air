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
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({required this.devices}) : super(Dio());

  final List<Device> devices;

  @override
  Future<List<Device>> getDevices() async => devices;
}
