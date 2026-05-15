import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../models/home.dart';

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(ref.read(dioProvider));
});

class HomeService {
  HomeService(this._dio);
  final Dio _dio;

  Future<List<Home>> getHomes() async {
    try {
      final res = await _dio.get('/homes');
      return (res.data as List).map((e) => Home.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Home> createHome(String name, {String? timezone}) async {
    try {
      final res = await _dio.post('/homes',
          data: {'name': name, 'timezone': timezone ?? 'Asia/Ho_Chi_Minh'});
      return Home.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Home> updateHome(String id, {String? name}) async {
    try {
      final res = await _dio.put('/homes/$id', data: {
        if (name != null) 'name': name,
      });
      return Home.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<void> deleteHome(String id) async {
    try {
      await _dio.delete('/homes/$id');
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<List<Room>> getRooms(String homeId) async {
    try {
      final res = await _dio.get('/homes/$homeId/rooms');
      return (res.data as List).map((e) => Room.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Room> createRoom(String homeId, String name) async {
    try {
      final res = await _dio
          .post('/homes/$homeId/rooms', data: {'name': name});
      return Room.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Room> updateRoom(String roomId, {String? name}) async {
    try {
      final res = await _dio.put('/rooms/$roomId', data: {
        if (name != null) 'name': name,
      });
      return Room.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await _dio.delete('/rooms/$roomId');
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<void> inviteMember(String homeId, String email,
      {String role = 'member'}) async {
    try {
      await _dio.post('/homes/$homeId/invite',
          data: {'email': email, 'role': role});
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
