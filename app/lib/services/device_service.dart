import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../models/command.dart';
import '../models/device.dart';
import '../models/telemetry.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService(ref.read(dioProvider));
});

class DeviceService {
  DeviceService(this._dio);
  final Dio _dio;

  Future<Device> registerDevice({
    required String deviceId,
    required String name,
    required String homeId,
    String? roomId,
  }) async {
    try {
      final res = await _dio.post('/devices', data: {
        'device_id': deviceId,
        'name': name,
        'home_id': homeId,
        if (roomId != null) 'room_id': roomId,
      });
      return Device.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// Returns true when the device has announced itself online via MQTT.
  /// Poll this after BLE credential write to confirm WiFi connect succeeded.
  Future<bool> checkAnnounce(String mac) async {
    try {
      final res = await _dio.get('/devices/announce/$mac');
      return (res.data as Map<String, dynamic>)['announced'] == true;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<List<Device>> getDevices() async {
    try {
      final res = await _dio.get('/devices');
      return (res.data as List).map((e) => Device.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<void> deleteDevice(String id) async {
    try {
      await _dio.delete('/devices/$id');
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<DeviceShadow> getShadow(String deviceId) async {
    try {
      final res = await _dio.get('/devices/$deviceId/shadow');
      return DeviceShadow.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<void> setDesired(
      String deviceId, Map<String, dynamic> desired) async {
    try {
      await _dio.put('/devices/$deviceId/shadow/desired', data: desired);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<String> sendCommand(
      String deviceId, Map<String, dynamic> payload) async {
    try {
      final res = await _dio
          .post('/devices/$deviceId/command', data: {'payload': payload});
      return res.data['command_id'] as String;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<List<Command>> getCommands(String deviceId,
      {int limit = 50, int offset = 0}) async {
    try {
      final res = await _dio.get('/devices/$deviceId/commands',
          queryParameters: {'limit': limit, 'offset': offset});
      return (res.data as List).map((e) => Command.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<List<TelemetryPoint>> getTelemetry(
    String deviceId, {
    DateTime? from,
    DateTime? to,
    String? agg,
    int limit = 1000,
  }) async {
    try {
      final now = DateTime.now();
      final res = await _dio.get('/devices/$deviceId/telemetry',
          queryParameters: {
            'from': (from ?? now.subtract(const Duration(hours: 24)))
                .toUtc()
                .toIso8601String(),
            'to': (to ?? now).toUtc().toIso8601String(),
            if (agg != null) 'agg': agg,
            'limit': limit,
          });
      return (res.data as List)
          .map((e) => TelemetryPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  AppException _map(DioException e) {
    if (e.error is AppException) return e.error as AppException;
    final msg = e.response?.data?['error'] as String? ?? 'Unknown error';
    return ApiException(e.response?.statusCode ?? 0, msg);
  }
}
