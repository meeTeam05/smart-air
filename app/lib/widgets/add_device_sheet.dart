import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// —————————————————————————————————————————————————————————————————————————
/// Simulated device found after a BLE/WiFi scan.
/// In production this would come from a real network discovery result.
/// —————————————————————————————————————————————————————————————————————————
class _DiscoveredDevice {
  final String name;
  final String model;
  final String mac;
  final int rssi; // signal strength -30 (close) … -90 (far)

  const _DiscoveredDevice({
    required this.name,
    required this.model,
    required this.mac,
    required this.rssi,
  });

  String get signalLabel {
    if (rssi >= -55) return 'Rất mạnh';
    if (rssi >= -70) return 'Tốt';
    return 'Yếu';
  }

  Color signalColor() {
    if (rssi >= -55) return const Color(0xFF10B981);
    if (rssi >= -70) return const Color(0xFFFF9500);
    return const Color(0xFFEF4444);
  }
}

/// —————————————————————————————————————————————————————————————————————————
/// AddDeviceSheet  — shows a BLE/WiFi scan UI
/// Returns `true` via Navigator.pop when a device is successfully added.
/// —————————————————————————————————————————————————————————————————————————
class AddDeviceSheet extends StatefulWidget {
  const AddDeviceSheet({super.key});

  @override
  State<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

enum _ScanState { idle, scanning, found, notFound }

class _AddDeviceSheetState extends State<AddDeviceSheet>
    with TickerProviderStateMixin {
  _ScanState _state = _ScanState.idle;
  _DiscoveredDevice? _found;

  // ── Ripple animation ────────────────────────────────────────────────────
  late final AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  // ── Simulated scan ──────────────────────────────────────────────────────
  // TODO: Replace with actual BLE (flutter_blue_plus) or mDNS / HTTP
  // discovery on mobile. On web we can't do BLE; show a helpful note.
  Future<void> _startScan() async {
    setState(() {
      _state = _ScanState.scanning;
      _found = null;
    });
    _ripple.repeat();

    // Simulate discovery: 3 s scan, then randomly finds the ESP32-S3.
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    _ripple.stop();

    // Simulated result: always finds the Smart Air device (demo).
    // In production: replace with real BLE scan result.
    final device = _DiscoveredDevice(
      name: 'Smart Air',
      model: 'ESP32-S3  ·  SA-01',
      mac: _fakeMac(),
      rssi: -48 - math.Random().nextInt(20),
    );

    setState(() {
      _state = _ScanState.found;
      _found = device;
    });
  }

  void _retry() {
    setState(() => _state = _ScanState.idle);
  }

  String _fakeMac() {
    final r = math.Random();
    return List.generate(
            6,
            (_) =>
                r.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
            child: Row(
              children: [
                Text(
                  'Thêm thiết bị',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: c.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 0, color: c.border),

          // ── Body ────────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                children: [
                  _buildScanArea(),
                  if (_state == _ScanState.found && _found != null) ...[
                    const SizedBox(height: 20),
                    _buildFoundCard(_found!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scan area ────────────────────────────────────────────────────────────
  Widget _buildScanArea() {
    final c = context.colors;
    return Column(
      children: [
        // ── Radar graphic ──────────────────────────────────────────────
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings (only visible while scanning)
              if (_state == _ScanState.scanning) ...[
                _RippleRing(controller: _ripple, delay: 0.0, maxRadius: 86),
                _RippleRing(controller: _ripple, delay: 0.33, maxRadius: 86),
                _RippleRing(controller: _ripple, delay: 0.66, maxRadius: 86),
              ],

              // Static background circle
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surfaceVar,
                  border: Border.all(
                    color: _state == _ScanState.scanning
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : c.border,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _state == _ScanState.found
                      ? Icons.check_circle_outline
                      : _state == _ScanState.notFound
                          ? Icons.search_off
                          : Icons.wifi_tethering,
                  size: 44,
                  color: _state == _ScanState.found
                      ? AppColors.online
                      : _state == _ScanState.scanning
                          ? AppColors.primary
                          : c.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Status text ────────────────────────────────────────────────
        Text(
          _stateTitle(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _stateSubtitle(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: c.textSecondary,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 20),

        // ── Action button ──────────────────────────────────────────────
        if (_state == _ScanState.idle)
          FilledButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.wifi_tethering, size: 18),
            label: const Text('Bắt đầu quét'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

        if (_state == _ScanState.scanning)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Đang quét mạng lân cận...',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ],
          ),

        if (_state == _ScanState.notFound)
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Quét lại'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(160, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  String _stateTitle() {
    switch (_state) {
      case _ScanState.idle:
        return 'Tìm thiết bị Smart Air';
      case _ScanState.scanning:
        return 'Đang quét...';
      case _ScanState.found:
        return 'Tìm thấy thiết bị!';
      case _ScanState.notFound:
        return 'Không tìm thấy thiết bị';
    }
  }

  String _stateSubtitle() {
    switch (_state) {
      case _ScanState.idle:
        return 'Đảm bảo thiết bị ESP32-S3 đang bật\nvà điện thoại ở gần thiết bị.';
      case _ScanState.scanning:
        return 'Đang tìm kiếm thiết bị Smart Air\ntrong mạng lân cận qua BLE / Wi-Fi...';
      case _ScanState.found:
        return 'Thiết bị đã sẵn sàng để kết nối.';
      case _ScanState.notFound:
        return 'Không tìm thấy thiết bị nào.\nKiểm tra nguồn điện và vị trí thiết bị.';
    }
  }

  // ── Found device card ─────────────────────────────────────────────────────
  Widget _buildFoundCard(_DiscoveredDevice dev) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Device icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.air, color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dev.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dev.model,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              // Signal badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.signal_wifi_4_bar,
                          color: dev.signalColor(), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        dev.signalLabel,
                        style:
                            TextStyle(fontSize: 11, color: dev.signalColor()),
                      ),
                    ],
                  ),
                  Text(
                    '${dev.rssi} dBm',
                    style: TextStyle(fontSize: 10, color: c.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(color: c.border, height: 0),
          const SizedBox(height: 10),

          const Row(
            children: [
              _InfoChip(icon: Icons.memory, label: 'ESP32-S3'),
              SizedBox(width: 8),
              _InfoChip(icon: Icons.bluetooth, label: 'BLE 5.0'),
              SizedBox(width: 8),
              _InfoChip(icon: Icons.wifi, label: 'Wi-Fi 4'),
            ],
          ),

          const SizedBox(height: 14),

          // MAC address
          Row(
            children: [
              Icon(Icons.tag, size: 12, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                'MAC: ${dev.mac}',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Add button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Thêm thiết bị này',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 8),

          TextButton(
            onPressed: _retry,
            child: Text(
              'Tìm thiết bị khác',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ripple ring ───────────────────────────────────────────────────────────────

class _RippleRing extends StatelessWidget {
  final AnimationController controller;
  final double delay; // 0.0 – 1.0
  final double maxRadius;

  const _RippleRing({
    required this.controller,
    required this.delay,
    required this.maxRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        // Offset the phase by [delay]
        double t = (controller.value + delay) % 1.0;
        final radius = maxRadius * t;
        final opacity = (1.0 - t).clamp(0.0, 1.0);

        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: opacity * 0.6),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceVar,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
