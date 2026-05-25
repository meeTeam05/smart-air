import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/icons.dart';
import '../design/palette.dart';
import '../design/text_styles.dart';
import '../design/tokens.dart';
import '../models/notification_item.dart';
import '../providers/notifications_provider.dart';
import '../widgets/atoms/empty_state.dart';
import '../widgets/shell/atmosphere_app_bar.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const AtmosphereAppBar.brand(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AtmosphereTokens.space16,
              AtmosphereTokens.space20,
              AtmosphereTokens.space16,
              AtmosphereTokens.space12,
            ),
            child: Text(
              'Notifications',
              style: AtmosphereTextStyles.pageTitle(c.ink),
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: AppIcons.notifications,
                      title: 'No notifications yet',
                      body:
                          'Important device events will appear here when devices go offline, finish commands, or complete OTA updates.',
                      primaryAction: 'Open devices',
                      onPrimaryAction: () => context.go('/home'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AtmosphereTokens.space16,
                        0,
                        AtmosphereTokens.space16,
                        AtmosphereTokens.space24,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _NotificationTile(item: item);
                      },
                      separatorBuilder: (_, __) => const SizedBox(
                        height: AtmosphereTokens.space12,
                      ),
                      itemCount: items.length,
                    ),
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AtmosphereTokens.space16,
                  0,
                  AtmosphereTokens.space16,
                  AtmosphereTokens.space24,
                ),
                itemBuilder: (_, __) => Container(
                  height: 108,
                  decoration: BoxDecoration(
                    color: c.line2,
                    borderRadius: BorderRadius.circular(
                      AtmosphereTokens.radiusCard,
                    ),
                  ),
                ),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AtmosphereTokens.space12),
                itemCount: 4,
              ),
              error: (error, _) => EmptyState(
                icon: AppIcons.warn,
                title: 'Failed to load notifications',
                body: error.toString(),
                primaryAction: 'Retry',
                onPrimaryAction: () => ref.invalidate(notificationsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
        onTap: () => context.push('/devices/${item.deviceId}'),
        child: Ink(
          padding: const EdgeInsets.all(AtmosphereTokens.space16),
          decoration: BoxDecoration(
            color: c.paper,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accentBackground(c),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icon,
                  color: _accentColor(c),
                  size: 20,
                ),
              ),
              const SizedBox(width: AtmosphereTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AtmosphereTextStyles.body(c.ink),
                    ),
                    const SizedBox(height: AtmosphereTokens.space6),
                    Text(
                      item.body,
                      style: AtmosphereTextStyles.caption(c.ink2),
                    ),
                    const SizedBox(height: AtmosphereTokens.space8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.deviceName,
                            style: AtmosphereTextStyles.caption(c.ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AtmosphereTokens.space12),
                        Text(
                          _formatTime(item.occurredAt),
                          style: AtmosphereTextStyles.caption(c.ink3),
                        ),
                      ],
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

  IconData get _icon => switch (item.type) {
        'device.online' || 'command.done' || 'ota.rebooting' => AppIcons.check,
        'device.offline' || 'command.timeout' => AppIcons.warn,
        'ota.failed' || 'command.error' => AppIcons.close,
        _ => AppIcons.notifications,
      };

  Color _accentBackground(AtmospherePalette c) => switch (item.severity) {
        'success' => c.brandTint,
        'warning' => c.warnTint,
        'danger' => c.dangerTint,
        _ => c.line2,
      };

  Color _accentColor(AtmospherePalette c) => switch (item.severity) {
        'success' => c.mint,
        'warning' => c.warn,
        'danger' => c.danger,
        _ => c.ink2,
      };

  String _formatTime(DateTime value) {
    final dt = value.toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hh:$mm';
  }
}
