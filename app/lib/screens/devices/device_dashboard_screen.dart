import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../models/device.dart';
import '../../providers/devices_provider.dart';
import '../../services/device_service.dart';
import '../../widgets/async_value_widget.dart';

class DeviceDashboardScreen extends ConsumerStatefulWidget {
  const DeviceDashboardScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<DeviceDashboardScreen> createState() =>
      _DeviceDashboardScreenState();
}

class _DeviceDashboardScreenState
    extends ConsumerState<DeviceDashboardScreen> {
  Timer? _timer;
  Device? _device; // cache — prevents flicker when devicesProvider reloads

  @override
  void initState() {
    super.initState();
    // Refresh device status once on enter (updates online field)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(devicesProvider);
    });
    // Auto-refresh shadow + device status every 10s.
    // devicesProvider invalidate is safe here — _device cache prevents UI flicker.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.read(shadowProvider(widget.deviceId).notifier).refresh();
      ref.invalidate(devicesProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _removeDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove device'),
        content: const Text(
            'This will unlink the device from your account. You can re-add it later by provisioning again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(devicesProvider.notifier).delete(widget.deviceId);
      if (mounted) context.go('/homes');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _syncTime() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await ref
          .read(deviceServiceProvider)
          .sendCommand(widget.deviceId, {'type': 'set_time', 'ts': ts});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time synced')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shadow = ref.watch(shadowProvider(widget.deviceId));

    // Update cache when fresh data arrives — never resets to null mid-reload
    final freshDevice = ref
        .watch(devicesProvider)
        .valueOrNull
        ?.where((d) => d.id == widget.deviceId)
        .firstOrNull;
    if (freshDevice != null) _device = freshDevice;
    final device = _device;

    final deviceTs = shadow.valueOrNull?.reported['ts'] as num?;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(device?.name ?? widget.deviceId,
            style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.push('/devices/${widget.deviceId}/chart'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () =>
                context.push('/devices/${widget.deviceId}/commands'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'sync_time') await _syncTime();
              if (value == 'remove') await _removeDevice();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'sync_time',
                child: Row(
                  children: [
                    Icon(Icons.access_time),
                    SizedBox(width: 8),
                    Text('Sync device time'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remove device', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(shadowProvider(widget.deviceId).notifier).refresh(),
            ref.refresh(devicesProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Online status + device time
              if (device != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: device.online
                                ? AppColors.online
                                : AppColors.offline,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            device.online ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: device.online
                                  ? AppColors.online
                                  : c.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (device.lastSeen != null)
                            Text(
                              'Last seen ${_relativeTime(device.lastSeen!)}',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 12),
                            ),
                        ],
                      ),
                      if (deviceTs != null && deviceTs.toInt() > 1704067200) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Device time: ${_formatDeviceTime(deviceTs.toInt())}',
                          style: TextStyle(color: c.textSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Sensor readings
              AsyncValueWidget(
                value: shadow,
                data: (s) => Row(
                  children: [
                    _SensorCard(
                      label: 'Temperature',
                      value: s.reported['temperature'] != null
                          ? '${(s.reported['temperature'] as num).toStringAsFixed(1)}°C'
                          : '--',
                      icon: Icons.thermostat,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    _SensorCard(
                      label: 'Humidity',
                      value: s.reported['humidity'] != null
                          ? '${(s.reported['humidity'] as num).toStringAsFixed(1)}%'
                          : '--',
                      icon: Icons.water_drop,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String _formatDeviceTime(int unixSec) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} '
        '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
