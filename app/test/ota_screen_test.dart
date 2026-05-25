import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/app_exception.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/ota.dart';
import 'package:smart_air/screens/devices/settings/ota_screen.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  testWidgets('shows offline state and OTA versions', (tester) async {
    final service = _FakeDeviceService(
      devices: const [
        Device(
          id: 'device-1',
          name: 'Living Room',
          homeId: 'home-1',
          online: false,
          firmwareVer: '0.1.1',
        ),
      ],
      catalog: const DeviceOtaCatalog(
        deviceId: 'device-1',
        currentVersion: '0.1.1',
        deviceOnline: false,
        versions: [
          OtaVersionInfo(
            version: '0.1.2',
            filename: '0.1.2.bin',
            url: 'https://updates.example.com/ota/0.1.2.bin',
          ),
          OtaVersionInfo(
            version: '0.1.1',
            filename: '0.1.1.bin',
            url: 'https://updates.example.com/ota/0.1.1.bin',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(service),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: OtaScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Current firmware'), findsOneWidget);
    expect(find.text('0.1.1'), findsWidgets);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('0.1.2'), findsOneWidget);
    expect(find.text('0.1.1.bin'), findsOneWidget);
    expect(find.text('Update'), findsNWidgets(2));
  });

  testWidgets('shows device offline error when update request fails', (
    tester,
  ) async {
    final service = _FakeDeviceService(
      devices: const [
        Device(
          id: 'device-1',
          name: 'Living Room',
          homeId: 'home-1',
          online: false,
          firmwareVer: '0.1.1',
        ),
      ],
      catalog: const DeviceOtaCatalog(
        deviceId: 'device-1',
        currentVersion: '0.1.1',
        deviceOnline: false,
        versions: [
          OtaVersionInfo(
            version: '0.1.2',
            filename: '0.1.2.bin',
            url: 'https://updates.example.com/ota/0.1.2.bin',
          ),
        ],
      ),
      startOtaError: const ApiException(409, 'device offline'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(service),
          realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: OtaScreen(deviceId: 'device-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Update'));
    await tester.pump();

    expect(find.text('device offline'), findsOneWidget);
    expect(service.startedVersions, ['0.1.2']);
  });
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({
    required this.devices,
    required this.catalog,
    this.startOtaError,
  }) : super(Dio());

  final List<Device> devices;
  final DeviceOtaCatalog catalog;
  final AppException? startOtaError;
  final List<String> startedVersions = [];

  @override
  Future<List<Device>> getDevices() async => devices;

  @override
  Future<DeviceOtaCatalog> getOtaCatalog(String deviceId) async => catalog;

  @override
  Future<void> startOtaUpdate(String deviceId, String version) async {
    startedVersions.add(version);
    if (startOtaError != null) throw startOtaError!;
  }
}
