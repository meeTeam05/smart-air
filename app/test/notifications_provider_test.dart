import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/notification_item.dart';
import 'package:smart_air/models/realtime_event.dart';
import 'package:smart_air/providers/notifications_provider.dart';
import 'package:smart_air/services/notification_service.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  test('notificationsProvider appends terminal realtime events to feed',
      () async {
    final events = StreamController<RealtimeEvent>.broadcast();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(
          _FakeNotificationService(items: const []),
        ),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    final subscription = container.listen(
      notificationsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(await container.read(notificationsProvider.future), isEmpty);

    events.add(
      RealtimeEvent(
        id: '42',
        type: 'command.updated',
        deviceId: 'device-1',
        occurredAt: DateTime(2026, 5, 24, 20, 55),
        payload: const {
          'command_id': 'cmd-1',
          'status': 'done',
          'payload': {
            'type': 'relay_set',
            'relay': 1,
            'state': true,
          },
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final items = container.read(notificationsProvider).value!;
    expect(items, hasLength(1));
    expect(items.single.id, '42');
    expect(items.single.title, 'Relay 1 turned on');
    expect(items.single.body, 'Command completed successfully.');
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
