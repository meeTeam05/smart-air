import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_air/core/router.dart';
import 'package:smart_air/core/secure_storage.dart';
import 'package:smart_air/main.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/core/api_client.dart';
import 'package:smart_air/services/auth_service.dart';
import 'package:smart_air/services/device_service.dart';
import 'package:smart_air/services/home_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  testWidgets('authenticated shell exposes only home notifications and profile tabs',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        deviceServiceProvider.overrideWithValue(_FakeDeviceService()),
        homeServiceProvider.overrideWithValue(_FakeHomeService()),
        realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SmartAirApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Automation'), findsNothing);
  });

  testWidgets('router configuration no longer includes removed shell or chart routes',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        deviceServiceProvider.overrideWithValue(_FakeDeviceService()),
        homeServiceProvider.overrideWithValue(_FakeHomeService()),
        realtimeEventsProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SmartAirApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final paths = _collectPaths(container.read(routerProvider).configuration.routes);
    expect(paths, isNot(contains('/automation')));
    expect(paths, isNot(contains('/devices/:id/chart')));
  });
}

Set<String> _collectPaths(List<RouteBase> routes) {
  final paths = <String>{};
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
    }
    paths.addAll(_collectPaths(route.routes));
  }
  return paths;
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(Dio());

  @override
  Future<void> logout() async {}
}

class _FakeSecureStorage extends SecureStorage {
  @override
  Future<String?> getRefreshToken() async => 'refresh-token';

  @override
  Future<Map<String, dynamic>?> getUserJson() async => const {
        'id': 'user-1',
        'email': 'test@example.com',
        'full_name': 'Test User',
      };
}

class _FakeDeviceService extends DeviceService {
  _FakeDeviceService() : super(Dio());
}

class _FakeHomeService extends HomeService {
  _FakeHomeService() : super(Dio());

  @override
  Future<List<Home>> getHomes() async => const [
        Home(id: 'home-1', name: 'My Home', ownerId: 'user-1'),
      ];
}
