// BLE data models for Smart Air firmware test mode.
// Used when the ESP32-S3 is running in test mode (no WiFi/MQTT).
// Replace placeholder UUIDs with real firmware UUIDs before production.

// ── GATT UUIDs ────────────────────────────────────────────────────────────────

/// Placeholder UUIDs — replace with actual values from ESP32-S3 firmware.
class SmartAirGatt {
  SmartAirGatt._();

  // TODO: Replace with real UUIDs from firmware GATT server
  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String tempCharUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const String humCharUuid = '0000ffe2-0000-1000-8000-00805f9b34fb';

  // Firmware advertises as 'SMART_AIR_<last 3 MAC bytes hex>', e.g. 'SMART_AIR_13ED8C'
  static const String deviceNamePrefix = 'SMART_AIR_';
}

// ── Device info ───────────────────────────────────────────────────────────────

/// Lightweight descriptor of a discovered BLE device.
class BleDeviceInfo {
  final String remoteId; // platform device ID (MAC on Android, UUID on iOS)
  final String name;
  final int rssi;

  const BleDeviceInfo({
    required this.remoteId,
    required this.name,
    required this.rssi,
  });

  /// Signal strength bucket: strong / medium / weak.
  RssiLevel get rssiLevel {
    if (rssi >= -60) return RssiLevel.strong;
    if (rssi >= -80) return RssiLevel.medium;
    return RssiLevel.weak;
  }
}

enum RssiLevel { strong, medium, weak }

// ── Sensor snapshot ───────────────────────────────────────────────────────────

/// A single reading from the ESP32-S3 sensor characteristic.
class SensorSnapshot {
  final double temperature; // °C
  final double humidity; // %RH
  final DateTime ts;

  const SensorSnapshot({
    required this.temperature,
    required this.humidity,
    required this.ts,
  });

  /// Parse raw bytes from the GATT characteristic.
  ///
  /// Expected encoding (8 bytes, little-endian):
  ///   bytes 0-3  → temperature as float32
  ///   bytes 4-7  → humidity as float32
  ///
  /// Returns null if the byte array is malformed.
  static SensorSnapshot? fromBytes(List<int> bytes) {
    if (bytes.length < 8) return null;
    // Convert 4-byte little-endian IEEE 754 float
    double readFloat(int offset) {
      final b = bytes.sublist(offset, offset + 4);
      final bits = b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24);
      // Reinterpret bit pattern as float via ByteData
      // dart:typed_data ByteData
      final bd = _ByteHelper.fromInt32(bits);
      return bd;
    }

    final temp = readFloat(0);
    final hum = readFloat(4);
    if (temp.isNaN || hum.isNaN) return null;
    return SensorSnapshot(temperature: temp, humidity: hum, ts: DateTime.now());
  }

  String get temperatureLabel => '${temperature.toStringAsFixed(1)}°C';
  String get humidityLabel => '${humidity.toStringAsFixed(0)}%';
}

// ── Internal helper ───────────────────────────────────────────────────────────

class _ByteHelper {
  static double fromInt32(int bits) {
    // Manual IEEE 754 decode to avoid dart:ffi dependency
    final sign = (bits >> 31) == 0 ? 1.0 : -1.0;
    final exponent = ((bits >> 23) & 0xFF) - 127;
    final mantissa = (bits & 0x7FFFFF) | 0x800000; // implicit leading 1
    if (exponent == -127) return 0.0; // zero / denormal
    return sign * mantissa * _pow2(exponent - 23);
  }

  static double _pow2(int exp) {
    double result = 1.0;
    if (exp >= 0) {
      for (int i = 0; i < exp; i++) {
        result *= 2.0;
      }
    } else {
      for (int i = 0; i < -exp; i++) {
        result /= 2.0;
      }
    }
    return result;
  }
}

// ── BLE scan/connection state ─────────────────────────────────────────────────

enum BleState {
  idle,
  scanning,
  connecting,
  reading,
  done,
  error,
  bluetoothOff,
  permissionDenied,
}
