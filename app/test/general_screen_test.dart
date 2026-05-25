import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/providers/devices_provider.dart';
import 'package:smart_air/screens/devices/settings/general_screen.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  testWidgets('shows room loading state while rooms are fetching', (
    WidgetTester tester,
  ) async {
    final roomsCompleter = Completer<List<Room>>();
    final fakeDeviceService = _FakeDeviceService(
      devices: const [
        Device(
          id: 'device-1',
          name: 'Living Room',
          homeId: 'home-1',
          roomId: 'room-1',
          online: true,
        ),
      ],
    );
    final fakeHomeService = _FakeHomeService(roomsCompleter: roomsCompleter);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeDeviceService),
          homeServiceProvider.overrideWithValue(fakeHomeService),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: GeneralSettingsScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Loading rooms...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    roomsCompleter.complete(const [
      Room(id: 'room-1', homeId: 'home-1', name: 'Bedroom'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Bedroom'), findsOneWidget);
  });
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({required this.devices}) : super(Dio());

  final List<Device> devices;

  @override
  Future<List<Device>> getDevices() async => devices;
}

class _FakeHomeService extends HomeService {
  _FakeHomeService({required this.roomsCompleter}) : super(Dio());

  final Completer<List<Room>> roomsCompleter;

  @override
  Future<List<Home>> getHomes() async => const [];

  @override
  Future<List<Room>> getRooms(String homeId) => roomsCompleter.future;
}
