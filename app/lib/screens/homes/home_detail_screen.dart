import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../providers/devices_provider.dart';
import '../../providers/homes_provider.dart';
import '../../widgets/async_value_widget.dart';

class HomeDetailScreen extends ConsumerWidget {
  const HomeDetailScreen({super.key, required this.homeId});
  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('Devices', style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Invite member',
            onPressed: () => _showInviteDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(devicesProvider);
        },
        child: AsyncValueWidget(
          value: devices,
          data: (allDevices) {
            final homeDevices =
                allDevices.where((d) => d.homeId == homeId).toList();
            if (homeDevices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.devices_other, size: 64, color: c.textSecondary),
                    const SizedBox(height: 12),
                    Text('No devices yet',
                        style: TextStyle(color: c.textSecondary)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: homeDevices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final device = homeDevices[i];
                return ListTile(
                  tileColor: c.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                    backgroundColor: device.online
                        ? AppColors.online.withValues(alpha: 0.15)
                        : AppColors.offline.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.air,
                      color:
                          device.online ? AppColors.online : AppColors.offline,
                    ),
                  ),
                  title: Text(device.name,
                      style: TextStyle(color: c.textPrimary)),
                  subtitle: Text(
                    device.online ? 'Online' : 'Offline',
                    style: TextStyle(
                        color: device.online
                            ? AppColors.online
                            : c.textSecondary),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, color: c.textSecondary),
                  onTap: () => context.push('/devices/${device.id}'),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/provision/scan?homeId=$homeId'),
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite Member'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Invite')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.isNotEmpty) {
      try {
        await ref
            .read(homesProvider.notifier)
            .inviteMember(homeId, ctrl.text.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invitation sent')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}
