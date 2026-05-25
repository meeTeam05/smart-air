import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../core/app_exception.dart';
import '../../providers/devices_provider.dart';
import '../../services/ble_service.dart';
import '../../services/device_service.dart';

class WifiSetupScreen extends ConsumerStatefulWidget {
  const WifiSetupScreen({super.key, required this.homeId, required this.mac});
  final String homeId;
  final String mac;

  @override
  ConsumerState<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends ConsumerState<WifiSetupScreen> {
  final _bleService = BleService();
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _provisioning = false;
  String _status = '';

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _bleService.disconnect();
    super.dispose();
  }

  Future<void> _provision() async {
    if (_ssidCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;

    setState(() {
      _provisioning = true;
      _status = 'Connecting to device…';
    });

    try {
      // Step 1 — BLE: send credentials, wait for device to connect WiFi.
      // sendCredentials() keeps BLE alive and returns the device's WiFi STA MAC
      // (device_id) and local IP once the notify arrives.
      await _bleService.connect(widget.mac);
      if (!mounted) return;
      setState(() => _status = 'Sending WiFi credentials…');
      final provision =
          await _bleService.sendCredentials(_ssidCtrl.text, _passCtrl.text);
      await _bleService.disconnect();

      final deviceId = provision.deviceId;

      if (!mounted) return;
      setState(() => _status = 'Registering device…');
      final registration =
          await ref.read(deviceServiceProvider).provisionDevice(
                deviceId: deviceId,
                name:
                    'Smart Air ${deviceId.substring(deviceId.length - 5).toUpperCase()}',
                homeId: widget.homeId,
              );

      if (!mounted) return;
      setState(() => _status = 'Sending MQTT credentials to device…');
      await ref.read(deviceServiceProvider).configureProvisionedDevice(
            host: provision.ip,
            deviceId: provision.deviceId,
            secretKey: registration.secretKey,
          );

      // Step 2 — Device connected WiFi; poll backend until MQTT status arrives.
      // The firmware connects MQTT → publishes online status.
      // Server MQTT bridge stores announcement in Redis (TTL 5 min).
      if (!mounted) return;
      setState(() => _status = 'Waiting for device to come online…');
      final deviceService = ref.read(deviceServiceProvider);
      bool announced = false;
      const pollInterval = Duration(seconds: 3);
      const maxWait = Duration(seconds: 60);
      final deadline = DateTime.now().add(maxWait);

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);
        announced = await deviceService.checkAnnounce(deviceId);
        if (announced) break;
      }

      if (!announced) {
        throw const NetworkException(
            'Device did not come online — check WiFi password and try again');
      }

      if (!mounted) return;
      try {
        ref.invalidate(devicesProvider);
      } on ApiException catch (e) {
        // 409 = device already registered — treat as success and navigate
        if (e.statusCode != 409) rethrow;
      }

      if (mounted) {
        context.go('/homes/${widget.homeId}');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      await _bleService.disconnect();
      if (mounted) setState(() => _provisioning = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _status = '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('WiFi Setup', style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Device: ${widget.mac}',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _ssidCtrl,
              decoration:
                  const InputDecoration(labelText: 'WiFi Network (SSID)'),
              enabled: !_provisioning,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'WiFi Password'),
              enabled: !_provisioning,
            ),
            const SizedBox(height: 32),
            if (_provisioning) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(_status,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary)),
            ] else
              FilledButton.icon(
                onPressed: _provision,
                icon: const Icon(Icons.wifi),
                label: const Text('Connect & Provision'),
              ),
          ],
        ),
      ),
    );
  }
}
