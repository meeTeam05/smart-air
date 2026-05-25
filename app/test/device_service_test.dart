import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/services/device_service.dart';

void main() {
  test('getTelemetry skips rows with missing or malformed timestamps', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.httpClientAdapter = _TelemetryAdapter(
      [
        {
          'ts': '2026-05-24T05:00:00.000Z',
          'temperature': 24.5,
        },
        {
          'temperature': 25.2,
        },
        {
          'ts': 'not-a-timestamp',
          'temperature': 25.9,
        },
      ],
    );
    final service = DeviceService(dio);

    final points = await service.getTelemetry('AA:BB:CC:DD:EE:FF');

    expect(points, hasLength(1));
    expect(points.single.temperature, 24.5);
    expect(points.single.ts, DateTime.parse('2026-05-24T05:00:00.000Z'));
  });
}

class _TelemetryAdapter implements HttpClientAdapter {
  _TelemetryAdapter(this.payload);

  final List<Map<String, dynamic>> payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
