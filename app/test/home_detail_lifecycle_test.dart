import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/api_client.dart';
import 'package:smart_air/core/router.dart';
import 'package:smart_air/core/secure_storage.dart';
import 'package:smart_air/design/icons.dart';
import 'package:smart_air/main.dart';
import 'package:smart_air/models/home.dart';
import 'package:smart_air/screens/profile/home_detail_screen.dart';
import 'package:smart_air/services/auth_service.dart';
import 'package:smart_air/services/home_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  testWidgets('editing a room name from profile home detail is lifecycle-safe',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
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

    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();

    expect(find.text('My Home'), findsOneWidget);
    await tester.tap(find.text('My Home'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeDetailScreen), findsOneWidget);
    expect(find.text('Living Room'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.edit).last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Bedroom');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Bedroom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(Dio());

  @override
  Future<void> logout() async {}
}

class _FakeSecureStorage extends SecureStorage {
  Map<String, dynamic>? _user = const {
    'id': 'user-1',
    'email': 'test@example.com',
    'full_name': 'Test User',
  };
  String? _refreshToken = 'refresh-token';

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<Map<String, dynamic>?> getUserJson() async => _user;

  @override
  Future<void> clear() async {
    _refreshToken = null;
    _user = null;
  }
}

class _FakeHomeService extends HomeService {
  _FakeHomeService() : super(Dio());

  final List<Home> _homes = const [
    Home(id: 'home-1', name: 'My Home', ownerId: 'user-1'),
  ];
  final List<Room> _rooms = const [
    Room(id: 'room-1', homeId: 'home-1', name: 'Living Room'),
  ];

  @override
  Future<List<Home>> getHomes() async => _homes;

  @override
  Future<List<Room>> getRooms(String homeId) async => _rooms;

  @override
  Future<Room> updateRoom(String roomId, {String? name}) async {
    return Room(id: roomId, homeId: 'home-1', name: name ?? 'Living Room');
  }
}
