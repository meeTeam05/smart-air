class AppConfig {
  AppConfig._();
}

class ApiConfig {
  ApiConfig._();

  static const String defaultApiBaseUrl = 'https://minhnhat05.xyz/api';
  static const String defaultMqttBrokerUri = 'wss://minhnhat05.xyz/mqtt';

  static const String localProvisioningScheme = 'http';
  static const String localInfoPath = '/api/info';
  static const String localConfigPath = '/api/config';
}

class BleConfig {
  BleConfig._();

  static const String provisioningServiceUuid =
      '0000fffe-0000-1000-8000-00805f9b34fb';
  static const String tempCharacteristicUuid =
      '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const String humidityCharacteristicUuid =
      '0000ffe2-0000-1000-8000-00805f9b34fb';
  static const String provisioningSsidCharacteristicUuid =
      '0000ff01-0000-1000-8000-00805f9b34fb';
  static const String provisioningPasswordCharacteristicUuid =
      '0000ff02-0000-1000-8000-00805f9b34fb';
  static const String provisioningNotifyCharacteristicUuid =
      '0000ff03-0000-1000-8000-00805f9b34fb';

  static const String provisioningDeviceNamePrefix = 'SMART_AIR_';
  static const String legacyDeviceNamePrefix = 'SmartAir-';

  static bool matchesProvisioningName(String name) {
    final normalized = name.trim();
    return normalized.startsWith(provisioningDeviceNamePrefix) ||
        normalized.startsWith(legacyDeviceNamePrefix);
  }
}
