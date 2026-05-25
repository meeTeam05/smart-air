import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../models/notification_item.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(dioProvider));
});

class NotificationService {
  NotificationService(this._dio);

  final Dio _dio;

  List<Map<String, dynamic>> _bodyAsMapList(Object? data) {
    if (data is! List) {
      throw const ApiException(0, 'Unexpected server response');
    }
    return data.map((item) {
      if (item is Map) return Map<String, dynamic>.from(item);
      throw const ApiException(0, 'Unexpected server response');
    }).toList();
  }

  Future<List<NotificationItem>> listNotifications({
    String? beforeId,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get('/notifications', queryParameters: {
        'limit': limit,
        if (beforeId != null && beforeId.isNotEmpty) 'before_id': beforeId,
      });
      return _bodyAsMapList(res.data).map(NotificationItem.fromJson).toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  AppException _map(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    final body = data is Map ? Map<String, dynamic>.from(data) : null;
    final message = body?['error'] as String? ?? e.message ?? 'Request failed';

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return NetworkException(message);
    }
    return ApiException(status, message);
  }
}
