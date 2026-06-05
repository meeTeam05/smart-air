import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/command.dart';
import 'package:smart_air/screens/devices/settings/calibration_wizard_screen.dart';
import 'package:smart_air/services/device_service.dart';

void main() {
  testWidgets('waits long enough for gas calibration confirmation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeDeviceService = _FakeDeviceService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(fakeDeviceService),
        ],
        child: const MaterialApp(
          home: CalibrationWizardScreen(deviceId: 'device-1', sensor: 'co'),
        ),
      ),
    );

    await tester.tap(find.text('Start calibration'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(fakeDeviceService.sentPayload, {'type': 'calibrate_co'});
    expect(fakeDeviceService.waitTimeout, const Duration(minutes: 7));
  });
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService() : super(Dio());

  Map<String, dynamic>? sentPayload;
  Duration? waitTimeout;

  @override
  Future<String> sendCommand(
      String deviceId, Map<String, dynamic> payload) async {
    sentPayload = payload;
    return 'calibration-command-1';
  }

  @override
  Future<Command> waitForCommandCompletion(
    String deviceId,
    String commandId, {
    Duration timeout = const Duration(minutes: 3),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    waitTimeout = timeout;
    return Command(
      id: commandId,
      payload: const {'type': 'calibrate_co'},
      status: 'done',
      createdAt: DateTime(2026, 6, 5, 17, 26),
      executedAt: DateTime(2026, 6, 5, 17, 29),
    );
  }
}
