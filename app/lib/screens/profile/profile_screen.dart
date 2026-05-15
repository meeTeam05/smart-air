import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';
import '../../design/icons.dart';
import '../../app_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/homes_provider.dart';
import '../../widgets/atoms/danger_button.dart';
import '../../widgets/shell/atmosphere_app_bar.dart';

/// Phase 11: Profile screen with Atmosphere design system.
/// Shows account info, homes list, app settings (theme/language), and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final homesState = ref.watch(homesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const AtmosphereAppBar.brand(),
      body: ListView(
        padding: const EdgeInsets.all(AtmosphereTokens.space16),
        children: [
          // Page title
          Text(
            'Profile',
            style: AtmosphereTextStyles.pageTitle(c.ink),
          ),
          const SizedBox(height: AtmosphereTokens.space20),

          // Account card
          Container(
            padding: const EdgeInsets.all(AtmosphereTokens.space20),
            decoration: BoxDecoration(
              color: c.paper,
              borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
              border: Border.all(color: c.line),
              boxShadow: AtmosphereTokens.shadowCard,
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.brandTint,
                  ),
                  child: Center(
                    child: Text(
                      _getInitial(user?.fullName, user?.email),
                      style: AtmosphereTextStyles.h1(c.brand),
                    ),
                  ),
                ),
                const SizedBox(width: AtmosphereTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user?.fullName?.isNotEmpty == true)
                        Text(
                          user!.fullName!,
                          style: AtmosphereTextStyles.h2(c.ink),
                        ),
                      Text(
                        user?.email ?? '',
                        style: AtmosphereTextStyles.caption(c.ink2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.edit, size: 20, color: c.ink3),
                  onPressed: () => _showEditProfile(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: AtmosphereTokens.space24),

          // Homes section
          Text(
            'HOMES',
            style: AtmosphereTextStyles.label(c.ink3),
          ),
          const SizedBox(height: AtmosphereTokens.space12),

          homesState.when(
            data: (homes) => _SettingsCard(
              children: [
                if (homes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AtmosphereTokens.space16),
                    child: Text(
                      'No homes yet',
                      style: AtmosphereTextStyles.caption(c.ink3),
                    ),
                  )
                else
                  ...homes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final home = entry.value;
                    return Column(
                      children: [
                        if (i > 0) Divider(height: 1, color: c.line),
                        _SettingRow(
                          icon: AppIcons.home,
                          label: home.name,
                          onTap: () => context.push('/profile/home/${home.id}'),
                        ),
                      ],
                    );
                  }),
              ],
            ),
            loading: () => Container(
              padding: const EdgeInsets.all(AtmosphereTokens.space16),
              decoration: BoxDecoration(
                color: c.paper,
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusCard),
                border: Border.all(color: c.line),
              ),
              child: Center(
                child: CircularProgressIndicator(color: c.brand),
              ),
            ),
            error: (_, __) => Container(
              padding: const EdgeInsets.all(AtmosphereTokens.space16),
              decoration: BoxDecoration(
                color: c.paper,
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusCard),
                border: Border.all(color: c.line),
              ),
              child: Text(
                'Failed to load homes',
                style: AtmosphereTextStyles.caption(c.danger),
              ),
            ),
          ),

          const SizedBox(height: AtmosphereTokens.space24),

          // App settings section
          Text(
            'APP SETTINGS',
            style: AtmosphereTextStyles.label(c.ink3),
          ),
          const SizedBox(height: AtmosphereTokens.space12),

          _SettingsCard(
            children: [
              _SettingRow(
                icon: AppIcons.cloud,
                label: 'Theme',
                trailing: _ThemeSelector(),
              ),

              _SettingRow(
                icon: AppIcons.notifications,
                label: 'Notifications',
                onTap: () => _showNotificationSettings(context),
              ),
              Divider(height: 1, color: c.line),
              _SettingRow(
                icon: AppIcons.info,
                label: 'About',
                onTap: () => _showAbout(context),
              ),
            ],
          ),

          const SizedBox(height: AtmosphereTokens.space32),

          // Logout button
          DangerButton(
            label: 'Logout',
            onPressed: () => _confirmLogout(context, ref),
          ),

          const SizedBox(height: AtmosphereTokens.space32),
        ],
      ),
    );
  }

  String _getInitial(String? fullName, String? email) {
    if (fullName?.isNotEmpty == true) {
      return fullName![0].toUpperCase();
    }
    if (email?.isNotEmpty == true) {
      return email![0].toUpperCase();
    }
    return '?';
  }

  void _showEditProfile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile editing coming soon')),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification settings coming soon')),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About'),
        content: const Text(
            'Smart Air v0.1.0\n\nIndoor air quality monitor and smart device controller.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
        border: Border.all(color: c.line),
      ),
      child: Column(children: children),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AtmosphereTokens.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AtmosphereTokens.space16,
          vertical: AtmosphereTokens.space16,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.ink2),
            const SizedBox(width: AtmosphereTokens.space12),
            Expanded(
              child: Text(
                label,
                style: AtmosphereTextStyles.body(c.ink),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(AppIcons.chev, size: 16, color: c.ink3),
          ],
        ),
      ),
    );
  }
}

// ── Theme selector ────────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeMode,
      builder: (context, mode, _) {
        return PopupMenuButton<ThemeMode>(
          initialValue: mode,
          onSelected: (value) => AppState.themeMode.value = value,
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: ThemeMode.system,
              child: Row(
                children: [
                  Icon(AppIcons.device, size: 16, color: c.ink2),
                  const SizedBox(width: AtmosphereTokens.space8),
                  const Text('System'),
                  if (mode == ThemeMode.system) ...[
                    const Spacer(),
                    Icon(AppIcons.check, size: 16, color: c.brand),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.light,
              child: Row(
                children: [
                  Icon(AppIcons.cloud, size: 16, color: c.ink2),
                  const SizedBox(width: AtmosphereTokens.space8),
                  const Text('Light'),
                  if (mode == ThemeMode.light) ...[
                    const Spacer(),
                    Icon(AppIcons.check, size: 16, color: c.brand),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.dark,
              child: Row(
                children: [
                  Icon(AppIcons.cloud, size: 16, color: c.ink2),
                  const SizedBox(width: AtmosphereTokens.space8),
                  const Text('Dark'),
                  if (mode == ThemeMode.dark) ...[
                    const Spacer(),
                    Icon(AppIcons.check, size: 16, color: c.brand),
                  ],
                ],
              ),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _themeName(mode),
                style: AtmosphereTextStyles.caption(c.ink2),
              ),
              const SizedBox(width: AtmosphereTokens.space4),
              Icon(AppIcons.chev, size: 16, color: c.ink3),
            ],
          ),
        );
      },
    );
  }

  String _themeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}
