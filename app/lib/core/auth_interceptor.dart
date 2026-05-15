import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_exception.dart';
import 'secure_storage.dart';

/// In-memory access token. Set by auth_provider after login/refresh/restore.
String? _accessToken;

void setAccessToken(String? token) => _accessToken = token;
String? getAccessToken() => _accessToken;

/// Incremented whenever a 401 cannot be recovered. auth_provider listens to
/// this signal to set state → null, which triggers the router redirect guard.
final forceLogoutSignalProvider = StateProvider<int>((_) => 0);

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._storage, this._ref);

  final Dio _dio;
  final SecureStorage _storage;
  final Ref _ref;
  Future<String>? _refreshFuture;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skipInterceptor'] == true) {
      handler.next(options);
      return;
    }
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;

    // Only attempt refresh on 401 from non-auth endpoints.
    // Auth endpoints (login, register, refresh) must propagate 401 as-is.
    final path = err.requestOptions.path;
    final isAuthPath = path.contains('/auth/');
    final alreadyRetried = err.requestOptions.extra['authRetried'] == true;
    if (statusCode != 401 || isAuthPath) {
      handler.next(_classified(err));
      return;
    }
    if (alreadyRetried) {
      handler.reject(_authError(err));
      return;
    }

    try {
      final newAccess = await _refreshAccessToken();
      final retryResponse = await _dio.fetch(
        err.requestOptions.copyWith(
          headers: {
            ...err.requestOptions.headers,
            'Authorization': 'Bearer $newAccess',
          },
          extra: {
            ...err.requestOptions.extra,
            'authRetried': true,
          },
        ),
      );
      handler.resolve(retryResponse);
    } on AuthException {
      handler.reject(_authError(err));
    } on DioException catch (retryErr) {
      if (retryErr.response?.statusCode == 401) {
        handler.reject(_authError(err));
        return;
      }
      handler.reject(_classified(retryErr));
    }
  }

  Future<String> _refreshAccessToken() {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final future = _performRefresh();
    _refreshFuture = future;
    future.whenComplete(() => _refreshFuture = null);
    return future;
  }

  Future<String> _performRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      await _forceLogout();
      throw const AuthException();
    }

    try {
      final res = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipInterceptor': true}),
      );

      final newAccess = res.data['accessToken'] as String?;
      if (newAccess == null || newAccess.isEmpty) {
        await _forceLogout();
        throw const AuthException();
      }

      final newRefresh = res.data['refreshToken'] as String?;
      setAccessToken(newAccess);
      if (newRefresh != null) {
        await _storage.saveRefreshToken(newRefresh);
      }
      return newAccess;
    } on DioException {
      await _forceLogout();
      throw const AuthException();
    }
  }

  Future<void> _forceLogout() async {
    setAccessToken(null);
    await _storage.clear();
    _ref.read(forceLogoutSignalProvider.notifier).update((s) => s + 1);
  }

  DioException _authError(DioException source) => DioException(
        requestOptions: source.requestOptions,
        error: const AuthException(),
        type: DioExceptionType.badResponse,
      );

  DioException _classified(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return DioException(
        requestOptions: err.requestOptions,
        error: const NetworkException(),
        type: err.type,
      );
    }
    return err;
  }
}
