import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../providers/devices_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Auto-refresh shadow every 10s
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(shadowProvider(widget.deviceId).notifier).refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendCommand(Map<String, dynamic> payload) async {
    try {
      await ref
          .read(commandsProvider(widget.deviceId).notifier)
          .send(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Command sent')),
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
    final devices = ref.watch(devicesProvider);

    final device = devices.valueOrNull
        ?.where((d) => d.id == widget.deviceId)
        .firstOrNull;

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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(shadowProvider(widget.deviceId).notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Online status
              if (device != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
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
              const SizedBox(height: 24),

              // Quick commands
              Text('Controls',
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: device?.online == true
                    ? () => _sendCommand({'power': true})
                    : null,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Power On'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: device?.online == true
                    ? () => _sendCommand({'power': false})
                    : null,
                icon: const Icon(Icons.power_off),
                label: const Text('Power Off'),
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
