import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/app_exception.dart';
import 'package:smart_air/services/device_service.dart';

void main() {
  test('getOtaCatalog parses device state and version list', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _DeviceOtaAdapter(
      responses: {
        '/devices/aa:bb:cc:dd:ee:ff/ota/versions': const _AdapterResponse.ok({
          'device_id': 'aa:bb:cc:dd:ee:ff',
          'current_version': '0.1.1',
          'device_online': false,
          'versions': [
            {
              'version': '0.1.2',
              'filename': '0.1.2.bin',
              'url': 'https://updates.example.com/ota/0.1.2.bin',
            },
            {
              'version': '0.1.1',
              'filename': '0.1.1.bin',
              'url': 'https://updates.example.com/ota/0.1.1.bin',
            },
          ],
        }),
      },
    );
    final service = DeviceService(dio);

    final catalog = await service.getOtaCatalog('AA:BB:CC:DD:EE:FF');

    expect(catalog.deviceId, 'aa:bb:cc:dd:ee:ff');
    expect(catalog.currentVersion, '0.1.1');
    expect(catalog.deviceOnline, isFalse);
    expect(catalog.versions, hasLength(2));
    expect(catalog.versions.first.version, '0.1.2');
  });

  test('getOtaCatalog throws ApiException for malformed response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _DeviceOtaAdapter(
      responses: {
        '/devices/aa:bb:cc:dd:ee:ff/ota/versions': const _AdapterResponse.ok({
          'device_id': 'aa:bb:cc:dd:ee:ff',
          'versions': 'bad',
        }),
      },
    );
    final service = DeviceService(dio);

    await expectLater(
      () => service.getOtaCatalog('AA:BB:CC:DD:EE:FF'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Unexpected server response',
        ),
      ),
    );
  });
}

class _DeviceOtaAdapter implements HttpClientAdapter {
  _DeviceOtaAdapter({required this.responses});

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

  final int statusCode;
  final Object body;
}
