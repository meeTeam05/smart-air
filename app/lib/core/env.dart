class Env {
  Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://minhnhat05.xyz/api',
  );

  static const mqttBrokerUri = String.fromEnvironment(
    'MQTT_BROKER_URI',
    defaultValue: 'wss://minhnhat05.xyz/mqtt',
  );
}
