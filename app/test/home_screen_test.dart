import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/device.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/screens/home_screen.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';

void main() {
  testWidgets('renders empty branch when there are no devices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(
            _FakeDeviceService(devices: const []),
          ),
          homeServiceProvider.overrideWithValue(_FakeHomeService()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No devices yet'), findsOneWidget);
    expect(find.text('Add a device'), findsOneWidget);
  });

  testWidgets('renders populated branch when devices exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(
            _FakeDeviceService(
              devices: const [
                Device(
                  id: 'device-1',
                  name: 'Bedroom Sensor',
                  homeId: 'home-1',
                  roomId: 'room-1',
                  online: true,
                ),
              ],
            ),
          ),
          homeServiceProvider.overrideWithValue(
            _FakeHomeService(
              roomsByHome: const {
                'home-1': [
                  Room(id: 'room-1', homeId: 'home-1', name: 'Bedroom'),
                ],
              },
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bedroom Sensor'), findsOneWidget);
    expect(find.text('Bedroom'), findsOneWidget);
    expect(find.text('View Detail'), findsOneWidget);
    expect(find.text('No devices yet'), findsNothing);
  });

  testWidgets('falls back when room lookup is missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceServiceProvider.overrideWithValue(
            _FakeDeviceService(
              devices: const [
                Device(
                  id: 'device-1',
                  name: 'Bedroom Sensor',
                  homeId: 'home-1',
                  roomId: 'room-unknown',
                  online: true,
                ),
              ],
            ),
          ),
          homeServiceProvider.overrideWithValue(
            _FakeHomeService(
              roomsByHome: const {
                'home-1': [
                  Room(id: 'room-1', homeId: 'home-1', name: 'Bedroom'),
                ],
              },
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Room unavailable'), findsOneWidget);
  });
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService({required this.devices}) : super(Dio());

  final List<Device> devices;

  @override
  Future<List<Device>> getDevices() async => devices;
}

class _FakeHomeService extends HomeService {
  _FakeHomeService({this.roomsByHome = const {}}) : super(Dio());

  final Map<String, List<Room>> roomsByHome;

  @override
  Future<List<Home>> getHomes() async => const [];

  @override
  Future<List<Room>> getRooms(String homeId) async =>
      roomsByHome[homeId] ?? const [];
}
