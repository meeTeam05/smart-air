import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/app_exception.dart';
import 'package:smart_air/services/auth_service.dart';

void main() {
  test('login throws ApiException for malformed success payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _AuthServiceAdapter(
      responses: {
        '/auth/login': _AdapterResponse.ok('not-an-object'),
      },
    );
    final service = AuthService(dio);

    await expectLater(
      () => service.login('a@example.com', 'pw'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('register throws ApiException for malformed success payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _AuthServiceAdapter(
      responses: {
        '/auth/register': _AdapterResponse.ok(['not', 'object']),
      },
    );
    final service = AuthService(dio);

    await expectLater(
      () => service.register('a@example.com', 'pw', 'Nhat'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('refresh ignores invalid optional refreshToken field type', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _AuthServiceAdapter(
      responses: {
        '/auth/refresh': _AdapterResponse.ok({
          'accessToken': 'fresh-token',
          'refreshToken': 42,
        }),
      },
    );
    final service = AuthService(dio);

    final result = await service.refresh('refresh-1');

    expect(result.accessToken, 'fresh-token');
    expect(result.refreshToken, isNull);
  });

  test('string error response does not crash exception mapping', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _AuthServiceAdapter(
      responses: {
        '/auth/login': _AdapterResponse.error(500, 'server exploded'),
      },
    );
    final service = AuthService(dio);

    await expectLater(
      () => service.login('a@example.com', 'pw'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unknown error',
        ),
      ),
    );
  });
}

class _AuthServiceAdapter implements HttpClientAdapter {
  _AuthServiceAdapter({required this.responses});

  final Map<String, _AdapterResponse> responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = responses[options.path];
    if (response == null) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    if (response.statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: response.statusCode,
          data: response.body,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterResponse {
  const _AdapterResponse(this.statusCode, this.body);

  const _AdapterResponse.ok(Object body) : this(200, body);
  const _AdapterResponse.error(int statusCode, Object body)
      : this(statusCode, body);

  final int statusCode;
  final Object body;
}
