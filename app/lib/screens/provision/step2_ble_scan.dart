import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../design/icons.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../services/ble_models.dart';
import '../../services/ble_service.dart';
import '../../widgets/atoms/card.dart';
import '../../widgets/atoms/empty_state.dart';
import '../../widgets/shell/ble_step_shell.dart';

class Step2BleScanScreen extends StatefulWidget {
  const Step2BleScanScreen({super.key, required this.homeId});

  final String homeId;

  @override
  State<Step2BleScanScreen> createState() => _Step2BleScanScreenState();
}

class _Step2BleScanScreenState extends State<Step2BleScanScreen> {
  final BleService _ble = BleService();
  final List<BleDeviceInfo> _devices = [];

  StreamSubscription<BleDeviceInfo>? _scanSub;
  Timer? _scanTimeout;

  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanTimeout?.cancel();
    _scanSub?.cancel();
    _ble.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    _scanTimeout?.cancel();
    await _scanSub?.cancel();
    await _ble.stopScan();

    setState(() {
      _devices.clear();
      _error = null;
      _connecting = false;
      _scanning = true;
    });

    final granted = await _ble.ensurePermissions();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _scanning = false;
        _error =
            'Bluetooth permission required. Enable Bluetooth and location access, then retry.';
      });
      return;
    }

    _scanSub = _ble.scan(timeout: const Duration(seconds: 12)).listen(
      (device) {
        if (!mounted) return;
        if (!BleConfig.matchesProvisioningName(device.name)) return;
        setState(() {
          if (_devices.every((d) => d.remoteId != device.remoteId)) {
            _devices.add(device);
            _devices.sort((a, b) => b.rssi.compareTo(a.rssi));
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _error = error.toString();
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _scanning = false);
      },
    );

    _scanTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      setState(() => _scanning = false);
    });
  }

  Future<void> _selectDevice(BleDeviceInfo device) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await _ble.connect(device.remoteId);
      if (!mounted) return;
      context.push(
        '/provision/wifi?homeId=${Uri.encodeComponent(widget.homeId)}&mac=${Uri.encodeComponent(device.remoteId)}&deviceId=${Uri.encodeComponent(device.remoteId)}',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDevices = _devices.isNotEmpty;

    return BleStepShell(
      currentStep: 1,
      title: 'Scan for nearby devices',
      subtitle:
          'We’ll find Smart Air units in provisioning mode and connect to the strongest one.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AtmosphereCard(
            padding: const EdgeInsets.all(AtmosphereTokens.space16),
            child: Column(
              children: [
                if (_scanning) ...[
                  const SizedBox(height: AtmosphereTokens.space8),
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: AtmosphereTokens.space16),
                  Text(
                    'Scanning…',
                    style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    'Tap a device to continue.',
                    style: TextStyle(color: c.ink2, fontSize: 13),
                  ),
                ] else if (_error != null) ...[
                  EmptyState(
                    icon: AppIcons.warn,
                    title: 'Scan failed',
                    body: _error!,
                  ),
                ] else if (!hasDevices) ...[
                  const EmptyState(
                    icon: AppIcons.bluetooth,
                    title: 'No devices found',
                    body: 'Keep the device in pairing mode and try again.',
                  ),
                ] else ...[
                  for (final device in _devices) ...[
                    _DeviceTile(
                      device: device,
                      busy: _connecting,
                      onTap: () => _selectDevice(device),
                    ),
                    const SizedBox(height: AtmosphereTokens.space12),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
      primaryLabel: _scanning ? 'Scanning…' : 'Scan again',
      primaryEnabled: !_scanning && !_connecting,
      onPrimary: _startScan,
      secondaryLabel: 'Back',
      onSecondary: () => context.pop(),
      onCancel: () => context.pop(),
      primaryLoading: _connecting,
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.busy,
    required this.onTap,
  });

  final BleDeviceInfo device;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
      child: AtmosphereCard(
        padding: const EdgeInsets.all(AtmosphereTokens.space16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.brandTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(AppIcons.bluetooth, color: c.brand),
            ),
            const SizedBox(width: AtmosphereTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.remoteId,
                    style: TextStyle(color: c.ink2, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AtmosphereTokens.space12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${device.rssi} dBm',
                  style: TextStyle(
                    color: c.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap to connect',
                  style: TextStyle(color: c.ink2, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
