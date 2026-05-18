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
}
