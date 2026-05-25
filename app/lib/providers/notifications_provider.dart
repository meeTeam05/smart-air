import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../models/notification_item.dart';
import '../models/realtime_event.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import 'devices_provider.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
        NotificationsNotifier.new);

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

class NotificationsNotifier extends AsyncNotifier<List<NotificationItem>> {
  late NotificationService _service;

  @override
  Future<List<NotificationItem>> build() async {
    _service = ref.read(notificationServiceProvider);
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (_, next) => next.whenData(_handleRealtimeEvent));
    return _service.listNotifications();
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    final current = state.valueOrNull;
    if (current == null) return;

    final item = _notificationFromRealtimeEvent(event);
    if (item == null) return;
    if (current.any((existing) => existing.id == item.id)) return;

    state = AsyncData([item, ...current]);
  }

  NotificationItem? _notificationFromRealtimeEvent(RealtimeEvent event) {
    final titleAndBody = _titleAndBodyForEvent(event);
    if (titleAndBody == null) return null;

    final deviceName = _deviceNameFor(event.deviceId);
    return NotificationItem(
      id: event.id,
      type: titleAndBody.type,
      deviceId: event.deviceId,
      deviceName: deviceName,
      title: titleAndBody.title,
      body: titleAndBody.body,
      severity: titleAndBody.severity,
      occurredAt: event.occurredAt,
      payload: event.payload,
    );
  }

  String _deviceNameFor(String deviceId) {
    final devices = ref.read(devicesProvider).valueOrNull ?? const <Device>[];
    for (final device in devices) {
      if (device.id == deviceId) return device.name;
    }
    return deviceId;
  }

  ({String type, String title, String body, String severity})?
      _titleAndBodyForEvent(RealtimeEvent event) {
    if (event.type == 'device.status') {
      final online = event.payload['online'] == true;
      return (
        type: online ? 'device.online' : 'device.offline',
        title: online ? 'Device came online' : 'Device went offline',
        body: online
            ? 'Device is connected and reporting.'
            : 'Device is no longer reporting.',
        severity: online ? 'success' : 'warning',
      );
    }

    if (event.type == 'ota.progress') {
      final status = event.payload['status'] as String?;
      if (status == 'rebooting') {
        return (
          type: 'ota.rebooting',
          title: 'OTA update applied',
          body: 'Device is rebooting to finish the update.',
          severity: 'success',
        );
      }
      if (status == 'failed') {
        final reason = event.payload['reason'] as String?;
        return (
          type: 'ota.failed',
          title: 'OTA update failed',
          body: reason == null || reason.trim().isEmpty
              ? 'Device reported an OTA failure.'
              : reason.trim(),
          severity: 'danger',
        );
      }
      return null;
    }

    if (event.type != 'command.updated') return null;

    final status = event.payload['status'] as String?;
    if (status != 'done' && status != 'error' && status != 'timeout') {
      return null;
    }
    final terminalStatus = status!;

    final payload = _commandPayload(event.payload);
    if (status == 'done') {
      return (
        type: 'command.done',
        title: _commandSuccessTitle(payload),
        body: 'Command completed successfully.',
        severity: 'success',
      );
    }

    final errorMessage = event.payload['error_message'] as String?;
    return (
      type: 'command.$status',
      title: _commandFailureTitle(payload, terminalStatus),
      body: terminalStatus == 'error' &&
              errorMessage != null &&
              errorMessage.trim().isNotEmpty
          ? errorMessage.trim()
          : terminalStatus == 'timeout'
              ? 'The device did not acknowledge the command in time.'
              : 'Device reported a command error.',
      severity: terminalStatus == 'timeout' ? 'warning' : 'danger',
    );
  }

  Map<String, dynamic> _commandPayload(Map<String, dynamic> eventPayload) {
    final nested = _asMap(eventPayload['payload']);
    if (nested.isNotEmpty) return nested;
    return _asMap(eventPayload['command_payload']);
  }

  String _commandSuccessTitle(Map<String, dynamic> payload) {
    switch (payload['type']) {
      case 'relay_set':
        final relay = payload['relay'] ?? '?';
        final state = payload['state'] == true ? 'on' : 'off';
        return 'Relay $relay turned $state';
      case 'device_mode':
        final mode = (payload['mode'] ?? '?').toString().toUpperCase();
        return 'Mode changed to $mode';
      case 'calibrate_co':
        return 'CO calibration completed';
      case 'calibrate_no2':
        return 'NO2 calibration completed';
      case 'set_time':
        return 'Device time synchronized';
      default:
        return 'Command completed';
    }
  }

  String _commandFailureTitle(Map<String, dynamic> payload, String status) {
    final suffix = status == 'timeout' ? 'timed out' : 'failed';
    switch (payload['type']) {
      case 'relay_set':
        final relay = payload['relay'] ?? '?';
        return 'Relay $relay command $suffix';
      case 'device_mode':
        return 'Mode change $suffix';
      case 'calibrate_co':
        return 'CO calibration $suffix';
      case 'calibrate_no2':
        return 'NO2 calibration $suffix';
      case 'set_time':
        return 'Time sync $suffix';
      default:
        return 'Command $suffix';
    }
  }
}
