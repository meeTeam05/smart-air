import 'app_config.dart';

class Env {
  Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: ApiConfig.defaultApiBaseUrl,
  );

  static const mqttBrokerUri = String.fromEnvironment(
    'MQTT_BROKER_URI',
    defaultValue: ApiConfig.defaultMqttBrokerUri,
  );

  static Uri get apiBaseUri => validateApiBaseUrl(apiBaseUrl);
  static Uri get mqttBrokerWsUri => validateMqttBrokerUri(mqttBrokerUri);

  static void validate() {
    apiBaseUri;
    mqttBrokerWsUri;
  }

  static Uri validateApiBaseUrl(String value) {
    return _validateAbsoluteUri(
      value,
      settingName: 'API_BASE_URL',
      allowedSchemes: const {'http', 'https'},
    );
  }

  static Uri validateMqttBrokerUri(String value) {
    return _validateAbsoluteUri(
      value,
      settingName: 'MQTT_BROKER_URI',
      allowedSchemes: const {'ws', 'wss'},
    );
  }

  static Uri _validateAbsoluteUri(
    String value, {
    required String settingName,
    required Set<String> allowedSchemes,
  }) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
      throw StateError('$settingName must be an absolute URI with a host');
    }

    if (!allowedSchemes.contains(uri.scheme)) {
      final allowed = allowedSchemes.toList()..sort();
      throw StateError('$settingName must use ${allowed.join(' or ')}');
    }

    return uri;
  }
}
