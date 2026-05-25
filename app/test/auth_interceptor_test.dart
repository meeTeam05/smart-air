import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/app_exception.dart';
import 'package:smart_air/core/auth_interceptor.dart';
import 'package:smart_air/core/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    setAccessToken('expired-token');
  });

  tearDown(() {
    setAccessToken(null);
  });

  test('malformed refresh payload forces logout instead of cast crash',
      () async {
    const rawStorage = FlutterSecureStorage();
    await rawStorage.write(key: 'refresh_token', value: 'refresh-1');

    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    final storage = SecureStorage();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final interceptorProvider =
        Provider<AuthInterceptor>((ref) => AuthInterceptor(dio, storage, ref));
    dio.interceptors.add(container.read(interceptorProvider));
    dio.httpClientAdapter = _AuthAdapter(
      refreshPayload: 'not-an-object',
      protectedPayload: const {'ok': true},
    );

    Object? thrown;
    try {
      await dio.get('/protected');
      fail('Expected auth refresh failure');
    } catch (error) {
      thrown = error;
    }

    expect(
      thrown,
      anyOf(
        isA<AuthException>(),
        isA<DioException>().having(
          (error) => error.error,
          'error',
          isA<AuthException>(),
        ),
      ),
    );

    expect(getAccessToken(), isNull);
    expect(await rawStorage.read(key: 'refresh_token'), isNull);
    expect(container.read(forceLogoutSignalProvider), 1);
  });

  test('invalid refreshToken field type is ignored during successful refresh',
      () async {
    const rawStorage = FlutterSecureStorage();
    await rawStorage.write(key: 'refresh_token', value: 'refresh-1');

    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    final storage = SecureStorage();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final interceptorProvider =
        Provider<AuthInterceptor>((ref) => AuthInterceptor(dio, storage, ref));
    dio.interceptors.add(container.read(interceptorProvider));
    dio.httpClientAdapter = _AuthAdapter(
      refreshPayload: const {
        'accessToken': 'fresh-token',
        'refreshToken': 42,
      },
      protectedPayload: const {'ok': true},
    );

    final response = await dio.get('/protected');

    expect(response.data, {'ok': true});
    expect(getAccessToken(), 'fresh-token');
    expect(await rawStorage.read(key: 'refresh_token'), 'refresh-1');
    expect(container.read(forceLogoutSignalProvider), 0);
  });
}

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter({
    required this.refreshPayload,
    required this.protectedPayload,
  });

  final Object refreshPayload;
  final Map<String, dynamic> protectedPayload;
  var _authorized = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      return _json(200, refreshPayload);
    }

    if (options.path == '/protected') {
      if (!_authorized) {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: const {'error': 'expired'},
          ),
          type: DioExceptionType.badResponse,
        );
      }
      return _json(200, protectedPayload);
    }

    throw DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: 404,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  ResponseBody _json(int statusCode, Object body) {
    if (body is Map<String, dynamic> && body['accessToken'] is String) {
      _authorized = true;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
