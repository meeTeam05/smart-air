import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/command.dart';
import '../models/device.dart';
import '../models/realtime_event.dart';
import '../models/telemetry.dart';
import '../services/device_service.dart';
import '../services/realtime_service.dart';

const _telemetryLiveWindow = Duration(minutes: 30);
const _telemetryLiveMaxPoints = 720;

enum _CopySentinel { unset }

String _normalizeDeviceId(String value) => value.trim().toLowerCase();

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  return null;
}

TelemetryPoint? _latestTelemetryPoint(List<TelemetryPoint> points) {
  if (points.isEmpty) return null;
  return points.reduce((a, b) => a.ts.isAfter(b.ts) ? a : b);
}

List<TelemetryPoint> _normalizeTelemetryPoints(
  List<TelemetryPoint> points, {
  DateTime? now,
}) {
  final cutoff = (now ?? DateTime.now()).subtract(_telemetryLiveWindow);
  final byIdentity = <String, ({TelemetryPoint point, int seq})>{};
  var seq = 0;
  for (final point in points) {
    if (point.ts.isBefore(cutoff)) continue;
    byIdentity[_telemetryIdentityKey(point)] = (point: point, seq: seq++);
  }
  final normalized = byIdentity.values.toList()
    ..sort((a, b) {
      final byTs = a.point.ts.compareTo(b.point.ts);
      if (byTs != 0) return byTs;
      return a.seq.compareTo(b.seq);
    });
  final values = normalized.map((entry) => entry.point).toList();
  if (values.length <= _telemetryLiveMaxPoints) return values;
  return values.sublist(values.length - _telemetryLiveMaxPoints);
}

String _telemetryIdentityKey(TelemetryPoint point) => [
      point.ts.millisecondsSinceEpoch,
      point.mode ?? '',
      point.temperature,
      point.humidity,
      point.coPpm,
      point.no2Ppm,
    ].join('|');

TelemetryPoint? _telemetryPointFromEvent(RealtimeEvent event) {
  final payload = event.payload;
  final tsRaw = payload['ts'];
  final ts = tsRaw is String ? DateTime.tryParse(tsRaw)?.toLocal() : null;
  if (ts == null) return null;
  return TelemetryPoint(
    ts: ts,
    temperature: _asDouble(payload['temperature']),
    humidity: _asDouble(payload['humidity']),
    coPpm: _asDouble(payload['co_ppm']),
    no2Ppm: _asDouble(payload['no2_ppm']),
    mode: payload['mode'] as String?,
  );
}

final devicesProvider =
    AsyncNotifierProvider<DevicesNotifier, List<Device>>(DevicesNotifier.new);

class DevicesNotifier extends AsyncNotifier<List<Device>> {
  late DeviceService _service;
  var _refreshInFlight = false;

  @override
  Future<List<Device>> build() async {
    _service = ref.read(deviceServiceProvider);
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (_, next) => next.whenData(_handleRealtimeEvent));
    return _service.getDevices();
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.type == 'replay.reset') {
      unawaited(refresh());
      return;
    }

    final current = state.valueOrNull;
    if (current == null) return;

    if (event.type == 'device.status') {
      final firmware = event.payload['firmware'] as String?;
      state = AsyncData([
        for (final device in current)
          if (device.id == event.deviceId)
            device.copyWith(
              online: event.payload['online'] == true,
              lastSeen: event.occurredAt,
              firmwareVer: firmware ?? device.firmwareVer,
            )
          else
            device,
      ]);
      return;
    }

    if (event.type != 'shadow.reported') return;
    final reported = _asMap(event.payload['reported']);
    state = AsyncData([
      for (final device in current)
        if (device.id == event.deviceId)
          device.copyWith(
            mode: reported['mode'] as String? ?? device.mode,
            relay1: _asBool(reported['relay_1']) ?? device.relay1,
            relay2: _asBool(reported['relay_2']) ?? device.relay2,
            relay3: _asBool(reported['relay_3']) ?? device.relay3,
          )
        else
          device,
    ]);
  }

  Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      state = await AsyncValue.guard(_service.getDevices);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<Device> register({
    required String deviceId,
    required String name,
    required String homeId,
    String? roomId,
  }) async {
    final device = await _service.registerDevice(
      deviceId: deviceId,
      name: name,
      homeId: homeId,
      roomId: roomId,
    );
    state = AsyncData([...state.valueOrNull ?? [], device]);
    return device;
  }

  Future<void> delete(String id) async {
    final normalizedDeviceId = _normalizeDeviceId(id);
    await _service.deleteDevice(normalizedDeviceId);
    state = AsyncData(
      (state.valueOrNull ?? [])
          .where((d) => d.id != normalizedDeviceId)
          .toList(),
    );
  }
}

final shadowProvider = AsyncNotifierProvider.autoDispose
    .family<ShadowNotifier, DeviceShadow, String>(ShadowNotifier.new);

class ShadowNotifier
    extends AutoDisposeFamilyAsyncNotifier<DeviceShadow, String> {
  late DeviceService _service;

  @override
  Future<DeviceShadow> build(String deviceId) async {
    _service = ref.read(deviceServiceProvider);
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (_, next) => next.whenData(_handleRealtimeEvent));
    return _service.getShadow(deviceId);
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.deviceId != arg || event.type != 'shadow.reported') return;
    final current = state.valueOrNull;
    if (current == null) return;

    final reported = _asMap(event.payload['reported']);
    final patch = _asMap(event.payload['patch']);
    state = AsyncData(
      current.copyWith(
        reported: {
          ...current.reported,
          ...patch,
          ...reported,
        },
        updatedAt: event.occurredAt,
      ),
    );
  }

  Future<void> refresh() async {
    // Do NOT set AsyncLoading — keeps previous data visible while fetching (no flicker).
    state = await AsyncValue.guard(() => _service.getShadow(arg));
  }
}

final commandsProvider = AsyncNotifierProvider.autoDispose
    .family<CommandsNotifier, List<Command>, String>(CommandsNotifier.new);

class CommandsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Command>, String> {
  late DeviceService _service;

  @override
  Future<List<Command>> build(String deviceId) async {
    _service = ref.read(deviceServiceProvider);
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (_, next) => next.whenData(_handleRealtimeEvent));
    return _service.getCommands(deviceId);
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.deviceId != arg || event.type != 'command.updated') return;

    final commandId = event.payload['command_id'] as String?;
    final status = event.payload['status'] as String?;
    if (commandId == null || status == null) return;

    final current = [...state.valueOrNull ?? const <Command>[]];
    final index = current.indexWhere((command) => command.id == commandId);
    final existing = index >= 0 ? current[index] : null;
    final payload = _asMap(event.payload['payload']);
    final nextCommand = Command(
      id: commandId,
      payload: payload.isNotEmpty ? payload : existing?.payload ?? const {},
      status: status,
      createdAt: existing?.createdAt ?? event.occurredAt,
      executedAt: status == 'done' || status == 'error' || status == 'timeout'
          ? event.occurredAt
          : existing?.executedAt,
    );

    if (index >= 0) {
      current[index] = nextCommand;
    } else {
      current.insert(0, nextCommand);
    }
    current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(current);
  }

  Future<String> send(Map<String, dynamic> payload) async {
    final id = await _service.sendCommand(arg, payload);
    ref.invalidateSelf();
    return id;
  }
}

final telemetryProvider = AsyncNotifierProvider.autoDispose
    .family<TelemetryNotifier, List<TelemetryPoint>, TelemetryParams>(
        TelemetryNotifier.new);

class TelemetryNotifier extends AutoDisposeFamilyAsyncNotifier<
    List<TelemetryPoint>, TelemetryParams> {
  late DeviceService _service;

  @override
  Future<List<TelemetryPoint>> build(TelemetryParams params) async {
    _service = ref.read(deviceServiceProvider);
    return _service.getTelemetry(
      params.deviceId,
      from: params.from,
      to: params.to,
      agg: params.agg,
    );
  }
}

final telemetryLiveProvider = AsyncNotifierProvider.autoDispose
    .family<TelemetryLiveNotifier, TelemetrySeriesState, String>(
        TelemetryLiveNotifier.new);

class TelemetryLiveNotifier
    extends AutoDisposeFamilyAsyncNotifier<TelemetrySeriesState, String> {
  late DeviceService _service;
  var _disposed = false;

  @override
  Future<TelemetrySeriesState> build(String deviceId) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _service = ref.read(deviceServiceProvider);
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (_, next) => next.whenData(_handleRealtimeEvent));
    ref.listen<RealtimeStatus>(
      realtimeConnectionStatusProvider,
      (_, next) => _setConnection(next),
    );

    final now = DateTime.now();
    final points = await _service.getTelemetry(
      deviceId,
      from: now.subtract(_telemetryLiveWindow),
      to: now,
      limit: _telemetryLiveMaxPoints,
    );
    final normalized = _normalizeTelemetryPoints(points, now: now);
    return TelemetrySeriesState(
      points: normalized,
      latest: _latestTelemetryPoint(normalized),
      initialLoading: false,
      lastUpdated: DateTime.now(),
      connection: ref.read(realtimeConnectionStatusProvider),
    );
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.type == 'replay.reset') {
      final current = state.valueOrNull;
      if (current != null) {
        state =
            AsyncData(current.copyWith(connection: RealtimeStatus.degraded));
      }
      unawaited(refreshSnapshot());
      return;
    }

    if (event.deviceId != arg) return;
    if (event.type != 'telemetry.point') return;
    final point = _telemetryPointFromEvent(event);
    if (point == null) return;

    final current = state.valueOrNull ?? const TelemetrySeriesState();
    final points = _normalizeTelemetryPoints([...current.points, point]);
    state = AsyncData(
      current.copyWith(
        points: points,
        latest: _latestTelemetryPoint(points),
        initialLoading: false,
        refreshing: false,
        lastError: null,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  void _setConnection(RealtimeStatus status) {
    final current = state.valueOrNull;
    if (current == null || current.connection == status) return;
    state = AsyncData(current.copyWith(connection: status));
  }

  Future<void> refreshSnapshot() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(refreshing: true, lastError: null));
    }

    try {
      final now = DateTime.now();
      final points = await _service.getTelemetry(
        arg,
        from: now.subtract(_telemetryLiveWindow),
        to: now,
        limit: _telemetryLiveMaxPoints,
      );
      if (_disposed) return;
      final normalized = _normalizeTelemetryPoints(points, now: now);
      state = AsyncData(
        TelemetrySeriesState(
          points: normalized,
          latest: _latestTelemetryPoint(normalized),
          initialLoading: false,
          refreshing: false,
          lastUpdated: DateTime.now(),
          connection: ref.read(realtimeConnectionStatusProvider),
        ),
      );
    } catch (err) {
      if (_disposed) return;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            refreshing: false,
            lastError: err,
          ),
        );
        return;
      }
      rethrow;
    }
  }
}

class TelemetrySeriesState {
  const TelemetrySeriesState({
    this.points = const [],
    this.latest,
    this.initialLoading = true,
    this.refreshing = false,
    this.lastError,
    this.lastUpdated,
    this.connection = RealtimeStatus.disconnected,
  });

  final List<TelemetryPoint> points;
  final TelemetryPoint? latest;
  final bool initialLoading;
  final bool refreshing;
  final Object? lastError;
  final DateTime? lastUpdated;
  final RealtimeStatus connection;

  TelemetrySeriesState copyWith({
    List<TelemetryPoint>? points,
    TelemetryPoint? latest,
    bool? initialLoading,
    bool? refreshing,
    Object? lastError = _CopySentinel.unset,
    DateTime? lastUpdated,
    RealtimeStatus? connection,
  }) {
    return TelemetrySeriesState(
      points: points ?? this.points,
      latest: latest ?? this.latest,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      lastError: lastError == _CopySentinel.unset ? this.lastError : lastError,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      connection: connection ?? this.connection,
    );
  }
}

final telemetryHistoryProvider = AsyncNotifierProvider.autoDispose.family<
    TelemetryHistoryNotifier,
    TelemetryHistoryState,
    TelemetryHistoryParams>(TelemetryHistoryNotifier.new);

class TelemetryHistoryNotifier extends AutoDisposeFamilyAsyncNotifier<
    TelemetryHistoryState, TelemetryHistoryParams> {
  late DeviceService _service;
  var _disposed = false;

  @override
  Future<TelemetryHistoryState> build(TelemetryHistoryParams params) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _service = ref.read(deviceServiceProvider);
    return _fetch(params);
  }

  Future<TelemetryHistoryState> _fetch(TelemetryHistoryParams params) async {
    final now = DateTime.now();
    final from = now.subtract(params.range.duration);
    final points = await _service.getTelemetry(
      params.deviceId,
      from: from,
      to: now,
      agg: params.range.agg,
    );
    return TelemetryHistoryState(
      points: points,
      from: from,
      to: now,
      refreshing: false,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> refreshHistory() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(refreshing: true, lastError: null));
    }
    try {
      final next = await _fetch(arg);
      if (_disposed) return;
      state = AsyncData(next);
    } catch (err) {
      if (_disposed) return;
      if (current != null) {
        state = AsyncData(current.copyWith(refreshing: false, lastError: err));
        return;
      }
      rethrow;
    }
  }
}

class TelemetryHistoryState {
  const TelemetryHistoryState({
    this.points = const [],
    required this.from,
    required this.to,
    this.refreshing = false,
    this.lastError,
    this.lastUpdated,
  });

  final List<TelemetryPoint> points;
  final DateTime from;
  final DateTime to;
  final bool refreshing;
  final Object? lastError;
  final DateTime? lastUpdated;

  TelemetryHistoryState copyWith({
    List<TelemetryPoint>? points,
    DateTime? from,
    DateTime? to,
    bool? refreshing,
    Object? lastError = _CopySentinel.unset,
    DateTime? lastUpdated,
  }) {
    return TelemetryHistoryState(
      points: points ?? this.points,
      from: from ?? this.from,
      to: to ?? this.to,
      refreshing: refreshing ?? this.refreshing,
      lastError: lastError == _CopySentinel.unset ? this.lastError : lastError,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

enum TelemetryHistoryRange {
  h1,
  h6,
  h24,
  d7,
  d30;

  Duration get duration => switch (this) {
        TelemetryHistoryRange.h1 => const Duration(hours: 1),
        TelemetryHistoryRange.h6 => const Duration(hours: 6),
        TelemetryHistoryRange.h24 => const Duration(hours: 24),
        TelemetryHistoryRange.d7 => const Duration(days: 7),
        TelemetryHistoryRange.d30 => const Duration(days: 30),
      };

  String? get agg => switch (this) {
        TelemetryHistoryRange.h1 => null,
        TelemetryHistoryRange.h6 => '5m',
        TelemetryHistoryRange.h24 => '15m',
        TelemetryHistoryRange.d7 => '1h',
        TelemetryHistoryRange.d30 => '6h',
      };

  double get xInterval => switch (this) {
        TelemetryHistoryRange.h1 => 15 * 60 * 1000.0,
        TelemetryHistoryRange.h6 => 60 * 60 * 1000.0,
        TelemetryHistoryRange.h24 => 6 * 3600 * 1000.0,
        TelemetryHistoryRange.d7 => 86400 * 1000.0,
        TelemetryHistoryRange.d30 => 7 * 86400 * 1000.0,
      };
}

class TelemetryHistoryParams {
  const TelemetryHistoryParams({
    required this.deviceId,
    required this.range,
  });

  final String deviceId;
  final TelemetryHistoryRange range;

  @override
  bool operator ==(Object other) =>
      other is TelemetryHistoryParams &&
      other.deviceId == deviceId &&
      other.range == range;

  @override
  int get hashCode => Object.hash(deviceId, range);
}

class TelemetryParams {
  const TelemetryParams({
    required this.deviceId,
    this.from,
    this.to,
    this.agg,
  });
  final String deviceId;
  final DateTime? from;
  final DateTime? to;
  final String? agg;

  @override
  bool operator ==(Object other) =>
      other is TelemetryParams &&
      other.deviceId == deviceId &&
      other.from == from &&
      other.to == to &&
      other.agg == agg;

  @override
  int get hashCode => Object.hash(deviceId, from, to, agg);
}
