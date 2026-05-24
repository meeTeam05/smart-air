import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/env.dart';

void main() {
  test('validateApiBaseUrl accepts absolute http urls', () {
    final uri = Env.validateApiBaseUrl('https://example.com/api');

    expect(uri.toString(), 'https://example.com/api');
  });

  test('validateApiBaseUrl rejects malformed urls', () {
    expect(
      () => Env.validateApiBaseUrl('not a url'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'API_BASE_URL must be an absolute URI with a host',
        ),
      ),
    );
  });

  test('validateMqttBrokerUri rejects non-websocket schemes', () {
    expect(
      () => Env.validateMqttBrokerUri('https://example.com/mqtt'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'MQTT_BROKER_URI must use ws or wss',
        ),
      ),
    );
  });
}
