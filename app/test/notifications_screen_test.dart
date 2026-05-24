import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/notification_item.dart';
import 'package:smart_air/models/realtime_event.dart';
import 'package:smart_air/screens/notifications_screen.dart';
import 'package:smart_air/services/notification_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  testWidgets(
      'notifications screen renders server-backed items with device name and time',
      (tester) async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(
          _FakeNotificationService(
            items: [
              NotificationItem(
                id: '42',
                type: 'command.done',
                deviceId: 'device-1',
                deviceName: 'Living Room Air',
                title: 'Relay 1 turned on',
                body: 'Command completed successfully.',
                severity: 'success',
                occurredAt: DateTime(2026, 5, 24, 20, 55),
              ),
            ],
          ),
        ),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Relay 1 turned on'), findsOneWidget);
    expect(find.text('Living Room Air'), findsOneWidget);
    expect(find.textContaining('20:55'), findsOneWidget);
    expect(find.text('Notifications feed unavailable'), findsNothing);
  });
}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({required this.items}) : super(Dio());

  final List<NotificationItem> items;

  @override
  Future<List<NotificationItem>> listNotifications({
    String? beforeId,
    int limit = 50,
  }) async =>
      items;
}
