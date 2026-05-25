import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/app_exception.dart';
import 'package:smart_air/services/device_service.dart';

void main() {
  test('provisionDevice throws ApiException for malformed object payload',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _DeviceServiceAdapter(
      responses: {
        '/devices': _AdapterResponse.ok('not-an-object'),
      },
    );
    final service = DeviceService(dio);

    await expectLater(
      () => service.provisionDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        name: 'Sensor',
        homeId: 'home-1',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('checkAnnounce throws ApiException for malformed payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _DeviceServiceAdapter(
      responses: {
        '/devices/announce/aa:bb:cc:dd:ee:ff': _AdapterResponse.ok('bad'),
      },
    );
    final service = DeviceService(dio);

    await expectLater(
      () => service.checkAnnounce('AA:BB:CC:DD:EE:FF'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('getDevices throws ApiException for malformed list payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _DeviceServiceAdapter(
      responses: {
        '/devices': _AdapterResponse.ok({'not': 'a-list'}),
      },
    );
    final service = DeviceService(dio);

    await expectLater(
      service.getDevices,
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('getShadow throws ApiException for malformed object payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _DeviceServiceAdapter(
      responses: {
        '/devices/aa:bb:cc:dd:ee:ff/shadow': _AdapterResponse.ok(['bad']),
      },
    );
    final service = DeviceService(dio);

    await expectLater(
      () => service.getShadow('AA:BB:CC:DD:EE:FF'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });

  test('sendCommand throws ApiException for malformed command response',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _DeviceServiceAdapter(
      responses: {
        '/devices/aa:bb:cc:dd:ee:ff/command': _AdapterResponse.ok(['bad']),
      },
    );
    final service = DeviceService(dio);

    await expectLater(
      () => service.sendCommand('AA:BB:CC:DD:EE:FF', const {'type': 'noop'}),
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
    dio.httpClientAdapter = _DeviceServiceAdapter(
      responses: {
        '/devices': _AdapterResponse.error(500, 'server exploded'),
      },
    );
    final service = DeviceService(dio);

    await expectLater(
      service.getDevices,
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

class _DeviceServiceAdapter implements HttpClientAdapter {
  _DeviceServiceAdapter({required this.responses});

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
