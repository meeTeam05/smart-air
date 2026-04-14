import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app_theme.dart';
import '../services/ble_models.dart';
import '../services/ble_service.dart';
import 'wifi_setup_screen.dart';

// ── Public result type ────────────────────────────────────────────────────────

/// Result returned to HomeScreen when a device is fully set up.
class BleConnectResult {
  final BleDeviceInfo device;
  final SensorSnapshot? snapshot;
  final bool isProvisioned;
  const BleConnectResult({
    required this.device,
    this.snapshot,
    this.isProvisioned = false,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class BleDeviceScanScreen extends StatefulWidget {
  const BleDeviceScanScreen({super.key});

  @override
  State<BleDeviceScanScreen> createState() => _BleDeviceScanScreenState();
}

class _BleDeviceScanScreenState extends State<BleDeviceScanScreen>
    with TickerProviderStateMixin {
  final _ble = BleService.instance;

  bool _isScanning = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isConnecting = false;

  // Keep ordered — first device found is the "featured" one
  final _orderedIds = <String>[];
  final _found = <String, BleDeviceInfo>{};

  StreamSubscription<BleDeviceInfo>? _scanSub;

  // Ripple animation while scanning
  late AnimationController _rippleCtrl;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _startScan();
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _fadeCtrl.dispose();
    _scanSub?.cancel();
    _ble.stopScan();
    super.dispose();
  }

  // ── Scan logic ──────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _hasError = false;
      _errorMessage = '';
      _orderedIds.clear();
      _found.clear();
      _isConnecting = false;
    });
    _fadeCtrl.reset();
    _rippleCtrl.repeat();

    final adapterState = await _ble.adapterState;
    if (adapterState != BluetoothAdapterState.on) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _hasError = true;
        _errorMessage =
            'Bluetooth is off.\nPlease enable Bluetooth and try again.';
      });
      return;
    }

    final granted = await _ble.ensurePermissions();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _hasError = true;
        _errorMessage =
            'Bluetooth permission required.\nSettings → Apps → Smart Air → Permissions';
      });
      return;
    }

    _scanSub = _ble.scan(timeout: const Duration(seconds: 12)).listen(
      (device) {
        if (!mounted) return;
        setState(() {
          if (!_orderedIds.contains(device.remoteId)) {
            _orderedIds.add(device.remoteId);
            // Animate in the first device card
            if (_orderedIds.length == 1) _fadeCtrl.forward();
          }
          _found[device.remoteId] = device;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        _rippleCtrl.stop();
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isScanning = false);
        _rippleCtrl.stop();
      },
    );
  }

  // ── Connect → immediately return to HomeScreen ─────────────────────────────

  Future<void> _connectDevice(BleDeviceInfo info) async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    // BLE connect attempt — ok if it fails (firmware in provisioning mode).
    SensorSnapshot? snap;
    try {
      snap = await _ble.connectAndRead(info);
    } catch (_) {}

    if (!mounted) return;

    // Device is in provisioning mode (no sensor service found) — collect WiFi creds.
    if (snap == null) {
      // Disconnect the failed connectAndRead attempt before WifiSetupScreen reconnects.
      await _ble.disconnect();
      if (!mounted) return;
      final provisioned = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => WifiSetupScreen(device: info)),
      );
      if (!mounted) return;
      Navigator.of(context).pop(BleConnectResult(
        device: info,
        snapshot: null,
        isProvisioned: provisioned == true,
      ));
      return;
    }

    // Device already provisioned — return with sensor snapshot.
    Navigator.of(context).pop(BleConnectResult(device: info, snapshot: snap));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final featured = _orderedIds.isNotEmpty ? _found[_orderedIds.first] : null;
    final others = _orderedIds.length > 1
        ? _orderedIds.skip(1).map((id) => _found[id]!).toList()
        : <BleDeviceInfo>[];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAppBar(c),
                Expanded(
                  child: _hasError
                      ? _buildErrorBody(c)
                      : featured == null
                          ? _buildScanningBody(c)
                          : _buildFoundBody(c, featured, others),
                ),
              ],
            ),
            // Full-screen loading overlay while connecting
            if (_isConnecting)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(AppPalette c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: c.textPrimary),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          Expanded(
            child: Text(
              'Add device',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          if (_isScanning)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh, color: c.textSecondary),
              onPressed: _startScan,
            ),
        ],
      ),
    );
  }

  // ── Scanning body ───────────────────────────────────────────────────────────

  Widget _buildScanningBody(AppPalette c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ripple rings
          AnimatedBuilder(
            animation: _rippleCtrl,
            builder: (_, __) {
              return SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final t = (_rippleCtrl.value - delay).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: (1 - t) * 0.4,
                      child: Container(
                        width: 60 + t * 140,
                        height: 60 + t * 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Discover nearby devices',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Auto-detecting nearby devices…',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Found body ──────────────────────────────────────────────────────────────

  Widget _buildFoundBody(
    AppPalette c,
    BleDeviceInfo featured,
    List<BleDeviceInfo> others,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // ── Featured device card (tap to connect) ─────────────────────────
          FadeTransition(
            opacity: _fadeCtrl,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () => _connectDevice(featured),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Device image
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Image.asset(
                          'assets/images/device_placeholder.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.air,
                            size: 80,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Device name
                      Text(
                        featured.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // MAC address
                      Text(
                        featured.remoteId,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textSecondary,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Other devices ─────────────────────────────────────────────────
          if (others.isNotEmpty) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Other devices (${others.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...others.map(
              (d) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _OtherDeviceTile(
                  device: d,
                  onTap: () => _connectDevice(d),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Error body ──────────────────────────────────────────────────────────────

  Widget _buildErrorBody(AppPalette c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: c.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Other device tile ─────────────────────────────────────────────────────────

class _OtherDeviceTile extends StatelessWidget {
  final BleDeviceInfo device;
  final VoidCallback onTap;
  const _OtherDeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'assets/images/device_placeholder.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.air,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(device.remoteId,
                        style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),
              _RssiPill(rssi: device.rssi),
            ],
          ),
        ),
      ),
    );
  }
}

// ── RSSI pill ─────────────────────────────────────────────────────────────────

class _RssiPill extends StatelessWidget {
  final int rssi;
  const _RssiPill({required this.rssi});

  Color _color() {
    if (rssi >= -60) return Colors.green;
    if (rssi >= -75) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi, size: 12, color: _color()),
          const SizedBox(width: 4),
          Text(
            '$rssi dBm',
            style: TextStyle(
                fontSize: 11, color: _color(), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
