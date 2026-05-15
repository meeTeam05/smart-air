import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/command.dart';
import '../models/device.dart';
import '../models/telemetry.dart';
import '../services/device_service.dart';

final devicesProvider =
    AsyncNotifierProvider<DevicesNotifier, List<Device>>(DevicesNotifier.new);

class DevicesNotifier extends AsyncNotifier<List<Device>> {
  late DeviceService _service;

  String _normalizeDeviceId(String value) => value.trim().toLowerCase();

  @override
  Future<List<Device>> build() async {
    _service = ref.read(deviceServiceProvider);
    return _service.getDevices();
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

final shadowProvider =
    AsyncNotifierProviderFamily<ShadowNotifier, DeviceShadow, String>(
        ShadowNotifier.new);

class ShadowNotifier extends FamilyAsyncNotifier<DeviceShadow, String> {
  late DeviceService _service;

  @override
  Future<DeviceShadow> build(String deviceId) async {
    _service = ref.read(deviceServiceProvider);
    return _service.getShadow(deviceId);
  }

  Future<void> refresh() async {
    // Do NOT set AsyncLoading — keeps previous data visible while fetching (no flicker).
    state = await AsyncValue.guard(() => _service.getShadow(arg));
  }
}

final commandsProvider =
    AsyncNotifierProviderFamily<CommandsNotifier, List<Command>, String>(
        CommandsNotifier.new);

class CommandsNotifier extends FamilyAsyncNotifier<List<Command>, String> {
  late DeviceService _service;

  @override
  Future<List<Command>> build(String deviceId) async {
    _service = ref.read(deviceServiceProvider);
    return _service.getCommands(deviceId);
  }

  Future<String> send(Map<String, dynamic> payload) async {
    final id = await _service.sendCommand(arg, payload);
    ref.invalidateSelf();
    return id;
  }
}

final telemetryProvider = AsyncNotifierProviderFamily<TelemetryNotifier,
    List<TelemetryPoint>, TelemetryParams>(TelemetryNotifier.new);

class TelemetryNotifier
    extends FamilyAsyncNotifier<List<TelemetryPoint>, TelemetryParams> {
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
