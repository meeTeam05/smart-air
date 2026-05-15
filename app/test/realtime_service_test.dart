import 'package:flutter_test/flutter_test.dart';
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
}
