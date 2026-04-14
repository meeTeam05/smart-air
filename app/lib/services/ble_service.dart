import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_models.dart';

/// Singleton that owns the full BLE lifecycle for Smart Air test mode.
///
/// Usage:
/// ```dart
/// final service = BleService.instance;
/// await service.ensurePermissions();   // request runtime perms
/// await for (final r in service.scan()) { ... }
/// final snap = await service.connectAndRead(deviceInfo);
/// service.dispose();
/// ```
class BleService {
  BleService._();
  static final instance = BleService._();

  BluetoothDevice? _device;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Returns true if all required BLE permissions are granted.
  ///
  /// Note: [Permission.bluetooth] (legacy, Android ≤ 11) is intentionally
  /// excluded — on Android 12+ it is not a runtime permission and
  /// [permission_handler] returns [PermissionStatus.denied] for it even when
  /// BLUETOOTH_SCAN / BLUETOOTH_CONNECT are fully granted.
  Future<bool> ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );
  }

  // ── Adapter state ──────────────────────────────────────────────────────────

  /// Single current adapter state snapshot.
  Future<BluetoothAdapterState> get adapterState async =>
      FlutterBluePlus.adapterState.first;

  // ── Scan ───────────────────────────────────────────────────────────────────

  /// Scans for nearby Smart Air BLE devices.
  ///
  /// Emits [BleDeviceInfo] for each result that matches [SmartAirGatt.deviceNamePrefix].
  /// The stream completes after [timeout] (default 10 s) or when [stopScan] is called.
  Stream<BleDeviceInfo> scan({Duration timeout = const Duration(seconds: 12)}) {
    final controller = StreamController<BleDeviceInfo>.broadcast();

    FlutterBluePlus.startScan(
      timeout: timeout,
      // androidScanMode: AndroidScanMode.lowLatency, // uncomment for faster scan
    );

    final sub = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final r in results) {
          // Prefer advName (from BLE advertisement/scan-response packet).
          // platformName is the Android cache — empty for unseen devices.
          final advName = r.advertisementData.advName.trim();
          final platformName = r.device.platformName.trim();
          final name = advName.isNotEmpty
              ? advName
              : platformName.isNotEmpty
                  ? platformName
                  : 'Unknown (${r.device.remoteId.str.substring(r.device.remoteId.str.length - 5)})';

          if (!name.contains(SmartAirGatt.deviceNamePrefix)) continue;

          controller.add(BleDeviceInfo(
            remoteId: r.device.remoteId.str,
            name: name,
            rssi: r.rssi,
          ));
        }
      },
      onError: controller.addError,
    );

    // Guard: only close the controller after the scan has actually started.
    // FlutterBluePlus.isScanning is a ValueStream that emits its current value
    // (false) immediately on listen(). Without this guard, the controller would
    // close before startScan() marks isScanning = true, dropping all results.
    bool scanStarted = false;
    StreamSubscription<bool>? isScanSub;
    isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (scanning) scanStarted = true;
      if (!scanning && scanStarted && !controller.isClosed) {
        sub.cancel();
        isScanSub?.cancel();
        controller.close();
      }
    });

    return controller.stream;
  }

  /// Stop an in-progress scan early.
  Future<void> stopScan() => FlutterBluePlus.stopScan();

  // ── Connect + read ─────────────────────────────────────────────────────────

  /// Connects to a device and reads one [SensorSnapshot].
  ///
  /// Throws a [BleException] on connection or read failure.
  Future<SensorSnapshot?> connectAndRead(BleDeviceInfo info) async {
    await disconnect(); // clean up any previous connection

    _device = BluetoothDevice.fromId(info.remoteId);

    try {
      // mtu: null — skip automatic requestMtu(512) which causes
      // PlatformException(requestMtu, device is disconnected) on some Android
      // versions when the peripheral doesn't respond to MTU exchange in time.
      await _device!.connect(timeout: const Duration(seconds: 10), mtu: null);
    } catch (e) {
      throw BleException('Connection failed: $e');
    }

    try {
      final services = await _device!.discoverServices();
      final svc = services.firstWhere(
        (s) => s.uuid.str128.toLowerCase() == SmartAirGatt.serviceUuid,
        orElse: () => throw BleException(
          'Smart Air GATT service not found.\n'
          'Check UUID: ${SmartAirGatt.serviceUuid}',
        ),
      );

      double? temp;
      double? hum;

      for (final char in svc.characteristics) {
        final uuid = char.uuid.str128.toLowerCase();

        if (uuid == SmartAirGatt.tempCharUuid) {
          final raw = await char.read();
          final snap = SensorSnapshot.fromBytes(raw);
          temp = snap?.temperature;
        }

        if (uuid == SmartAirGatt.humCharUuid) {
          final raw = await char.read();
          final snap = SensorSnapshot.fromBytes(raw);
          hum = snap?.humidity;
        }
      }

      if (temp == null || hum == null) return null;

      return SensorSnapshot(
        temperature: temp,
        humidity: hum,
        ts: DateTime.now(),
      );
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException('Read failed: $e');
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  /// Disconnects from the current device (no-op if not connected).
  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {
        // Ignore disconnect errors — device may already be gone
      }
      _device = null;
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopScan();
    await disconnect();
    await _adapterSub?.cancel();
    _adapterSub = null;
  }
}

// ── Exception ─────────────────────────────────────────────────────────────────

class BleException implements Exception {
  final String message;
  const BleException(this.message);

  @override
  String toString() => 'BleException: $message';
}
