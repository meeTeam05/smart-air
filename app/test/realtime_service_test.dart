import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/models/realtime_event.dart';
import 'package:smart_air/services/realtime_service.dart';

void main() {
  test('SseDecoder ignores comments and parses multi-line data frames', () {
    final decoder = SseDecoder();

    final events = [
      ...decoder.add(': connected\n\nid: 4'),
      ...decoder.add('2\nevent: telemetry.point\n'),
      ...decoder.add(
        'data: {\n'
        'data: "id":"ignored",\n'
        'data: "type":"ignored",\n'
        'data: "device_id":"aa:bb:cc:dd:ee:ff",\n'
        'data: "occurred_at":"2026-05-15T10:00:00.000Z",\n'
        'data: "payload":{"temperature":27.4}\n'
        'data: }\n\n',
      ),
    ];

    expect(events, hasLength(1));
    expect(events.single.id, '42');
    expect(events.single.type, 'telemetry.point');
    expect(events.single.deviceId, 'aa:bb:cc:dd:ee:ff');
    expect(events.single.payload['temperature'], 27.4);
  });

  test('SseDecoder skips malformed data frames and keeps parsing', () {
    final decoder = SseDecoder();

    final malformed = decoder.add(
      'id: 41\n'
      'event: telemetry.point\n'
      'data: not-json\n\n',
    );
    final valid = decoder.add(
      'id: 42\n'
      'event: telemetry.point\n'
      'data: {"device_id":"aa:bb:cc:dd:ee:ff","occurred_at":"2026-05-15T10:00:00.000Z","payload":{"temperature":28.1}}\n\n',
    );

    expect(malformed, isEmpty);
    expect(valid, hasLength(1));
    expect(valid.single.id, '42');
    expect(valid.single.payload['temperature'], 28.1);
  });

  test('SseDecoder tolerates missing occurred_at in otherwise valid frames',
      () {
    final decoder = SseDecoder();

    final events = decoder.add(
      'id: 43\n'
      'event: telemetry.point\n'
      'data: {"device_id":"aa:bb:cc:dd:ee:ff","payload":{"temperature":28.1}}\n\n',
    );

    expect(events, hasLength(1));
    expect(events.single.id, '43');
    expect(events.single.occurredAt,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal());
    expect(events.single.payload['temperature'], 28.1);
  });

  test('watchEvents stops promptly when cancelled during reconnect backoff',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    final adapter = _FailingRealtimeAdapter();
    dio.httpClientAdapter = adapter;
    final service = RealtimeService(dio);
    final cancelToken = CancelToken();
    final statuses = <RealtimeStatus>[];

    final done = service
        .watchEvents(
          cancelToken: cancelToken,
          onStatus: statuses.add,
          initialReconnectDelay: const Duration(seconds: 5),
        )
        .drain<void>();

    await adapter.requested.future;
    while (!statuses.contains(RealtimeStatus.disconnected)) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
        statuses,
        containsAllInOrder([
          RealtimeStatus.connecting,
          RealtimeStatus.disconnected,
        ]));

    cancelToken.cancel();

    await expectLater(
      done.timeout(const Duration(milliseconds: 200)),
      completes,
    );
    expect(adapter.calls, 1);
  });
}

class _FailingRealtimeAdapter implements HttpClientAdapter {
  final requested = Completer<void>();
  var calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (!requested.isCompleted) {
      requested.complete();
    }
    throw DioException(
      requestOptions: options,
      error: const SocketException('network down'),
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}
