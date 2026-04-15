import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../app_state.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    (user?.fullName?.isNotEmpty == true
                            ? user!.fullName![0]
                            : user?.email[0] ?? '?')
                        .toUpperCase(),
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user?.fullName?.isNotEmpty == true)
                        Text(user!.fullName!,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                      Text(user?.email ?? '',
                          style: TextStyle(
                              color: c.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Theme toggle
          _SettingsTile(
            icon: Icons.brightness_6_outlined,
            label: 'Dark Mode',
            trailing: Switch(
              value: AppState.themeMode.value == ThemeMode.dark,
              onChanged: (v) {
                AppState.themeMode.value =
                    v ? ThemeMode.dark : ThemeMode.light;
              },
              activeThumbColor: AppColors.primary,
            ),
          ),

          const SizedBox(height: 8),

          // Logout
          _SettingsTile(
            icon: Icons.logout,
            label: 'Logout',
            iconColor: AppColors.offline,
            labelColor: AppColors.offline,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout')),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      tileColor: c.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: iconColor ?? c.textSecondary),
      title: Text(label,
          style: TextStyle(color: labelColor ?? c.textPrimary)),
      trailing: trailing ?? (onTap != null
          ? Icon(Icons.chevron_right, color: c.textSecondary)
          : null),
      onTap: onTap,
    );
  }
}
