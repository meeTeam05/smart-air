import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../providers/devices_provider.dart';
import '../../services/ble_service.dart';

class WifiSetupScreen extends ConsumerStatefulWidget {
  const WifiSetupScreen(
      {super.key, required this.homeId, required this.mac});
  final String homeId;
  final String mac;

  @override
  ConsumerState<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends ConsumerState<WifiSetupScreen> {
  final _bleService = BleService();
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _provisioning = false;
  String _status = '';

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
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
      // Connect via BLE
      await _bleService.connect(widget.mac);
      setState(() => _status = 'Sending WiFi credentials…');

      // Send credentials via GATT
      await _bleService.sendCredentials(_ssidCtrl.text, _passCtrl.text);
      setState(() => _status = 'Waiting for device to connect… (30s)');

      // Wait for notify with timeout
      final json = await _bleService.notifyStream
          .timeout(const Duration(seconds: 30))
          .firstWhere((msg) => msg.contains('"status"'));

      final data = jsonDecode(json) as Map<String, dynamic>;
      if (data['status'] != 'ok') throw Exception('Provisioning failed');

      setState(() => _status = 'Registering device…');

      // Ask for device name
      final name = await _askDeviceName();
      if (name == null || !mounted) return;

      await ref.read(devicesProvider.notifier).register(
            deviceId: widget.mac,
            name: name,
            homeId: widget.homeId,
          );

      if (mounted) {
        context.go('/devices/${Uri.encodeComponent(widget.mac)}');
      }
    } on TimeoutException {
      _showError('Timed out — device did not respond in 30 seconds');
    } catch (e) {
      _showError(e.toString());
    } finally {
      await _bleService.disconnect();
      if (mounted) setState(() => _provisioning = false);
    }
  }

  Future<String?> _askDeviceName() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Name this device'),
        content: TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. Living Room Air Monitor'),
        ),
        actions: [
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _status = '');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
              decoration: const InputDecoration(labelText: 'WiFi Network (SSID)'),
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
