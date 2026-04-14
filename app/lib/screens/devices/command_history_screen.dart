import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../models/command.dart';
import '../../providers/devices_provider.dart';
import '../../widgets/async_value_widget.dart';

class CommandHistoryScreen extends ConsumerWidget {
  const CommandHistoryScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final commands = ref.watch(commandsProvider(deviceId));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('Command History', style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(commandsProvider(deviceId)),
        child: AsyncValueWidget(
          value: commands,
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 64, color: c.textSecondary),
                    const SizedBox(height: 12),
                    Text('No commands yet',
                        style: TextStyle(color: c.textSecondary)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _CommandTile(cmd: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.cmd});
  final Command cmd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _StatusBadge(status: cmd.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cmd.payload.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join(', '),
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(cmd.createdAt),
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'done' => (AppColors.online, 'Done'),
      'sent' => (AppColors.primary, 'Sent'),
      'failed' => (AppColors.offline, 'Failed'),
      _ => (AppColors.warning, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
