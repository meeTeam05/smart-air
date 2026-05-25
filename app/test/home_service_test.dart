import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/app_exception.dart';
import 'package:smart_air/services/home_service.dart';

void main() {
  test('getHomes throws ApiException for malformed list payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _HomeServiceAdapter(
      responses: {
        '/homes': _AdapterResponse.ok('not-a-list'),
      },
    );
    final service = HomeService(dio);

    await expectLater(
      service.getHomes,
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('createHome throws ApiException for malformed object payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _HomeServiceAdapter(
      responses: {
        '/homes': _AdapterResponse.ok(['not', 'object']),
      },
    );
    final service = HomeService(dio);

    await expectLater(
      () => service.createHome('My Home'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('getRooms throws ApiException for malformed room list payload',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _HomeServiceAdapter(
      responses: {
        '/homes/home-1/rooms': _AdapterResponse.ok({'not': 'a-list'}),
      },
    );
    final service = HomeService(dio);

    await expectLater(
      () => service.getRooms('home-1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('string error response does not crash exception mapping', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _HomeServiceAdapter(
      responses: {
        '/homes': _AdapterResponse.error(500, 'server exploded'),
      },
    );
    final service = HomeService(dio);

    await expectLater(
      service.getHomes,
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

class _HomeServiceAdapter implements HttpClientAdapter {
  _HomeServiceAdapter({required this.responses});

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
        response: Response(requestOptions: options, statusCode: 404),
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
