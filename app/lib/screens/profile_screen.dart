import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../app_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  String _userName = 'User';

  String get _theme =>
      AppState.themeModeLabels[
          AppState.keyFromThemeMode(AppState.themeMode.value)] ??
      'Dark';

  AppPalette get c => context.colors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── User header ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _editUserName,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _userName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.edit_outlined,
                                  color: c.textSecondary, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Account & app settings',
                          style:
                              TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar
                  GestureDetector(
                    onTap: _editUserName,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.surfaceVar,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Settings sections ────────────────────────────────────────
              const _SectionLabel('Account'),
              _SettingsSection(items: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  label: 'Account info',
                  onTap: _editUserName,
                  showDivider: false,
                ),
              ]),

              const SizedBox(height: 16),

              const _SectionLabel('App'),
              _SettingsSection(items: [
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  value: _notificationsEnabled ? 'On' : 'Off',
                  onTap: _showNotifSettings,
                ),
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'Appearance',
                  value: _theme,
                  onTap: _showThemePicker,
                  showDivider: false,
                ),
              ]),

              const SizedBox(height: 16),

              const _SectionLabel('Support'),
              _SettingsSection(items: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  label: 'Help & feedback',
                  onTap: _showHelpInfo,
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  label: 'About',
                  value: 'v0.5.0',
                  onTap: _showAbout,
                  showDivider: false,
                ),
              ]),

              const SizedBox(height: 24),

              // ── Sign out ─────────────────────────────────────────────────
              Center(
                child: OutlinedButton.icon(
                  onPressed: _showSignOutConfirm,
                  icon: Icon(Icons.logout, size: 16, color: c.textSecondary),
                  label: Text(
                    'Sign out',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _editUserName() {
    final ctrl = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Display name', style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: c.textSecondary),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) setState(() => _userName = name);
              Navigator.pop(ctx);
            },
            child:
                const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showNotifSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHandle(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Notifications',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary)),
                    ],
                  ),
                ),
                Divider(height: 0, color: c.border),
                SwitchListTile(
                  activeThumbColor: AppColors.primary,
                  title: Text('Enable notifications',
                      style: TextStyle(color: c.textPrimary)),
                  subtitle: Text('Receive alerts from devices',
                      style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  value: _notificationsEnabled,
                  onChanged: (v) {
                    setLocal(() {});
                    setState(() => _notificationsEnabled = v);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHandle(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Appearance',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary)),
                ),
                Divider(height: 0, color: c.border),
                ...AppState.themeModeLabels.entries.map(
                  (e) {
                    final mode = AppState.themeModeFromKey(e.key);
                    final selected = AppState.themeMode.value == mode;
                    final icon = e.key == 'dark'
                        ? Icons.dark_mode
                        : e.key == 'light'
                            ? Icons.light_mode
                            : Icons.settings_brightness;
                    return ListTile(
                      leading: Icon(icon,
                          color: selected ? AppColors.primary : c.textSecondary,
                          size: 20),
                      title:
                          Text(e.value, style: TextStyle(color: c.textPrimary)),
                      trailing: selected
                          ? const Icon(Icons.check,
                              color: AppColors.primary, size: 18)
                          : null,
                      onTap: () {
                        AppState.themeMode.value = mode;
                        setLocal(() {});
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHandle(),
                Text('Help & feedback',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  'Smart Air is an app for managing smart air quality devices.\n\n'
                  'For issues, contact us at:\n'
                  '• Email: support@smart-air.vn\n'
                  '• GitHub: github.com/smart-air',
                  style: TextStyle(
                      fontSize: 13, color: c.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child:
                        Text('Close', style: TextStyle(color: c.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Smart Air',
      applicationVersion: 'v0.5.0',
      applicationLegalese: '© 2026 MinhNhat & BaoViet',
    );
  }

  void _showSignOutConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Sign out', style: TextStyle(color: c.textPrimary)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Sign out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: c.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final List<_SettingsTile> items;
  const _SettingsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(children: items),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(icon, color: c.textSecondary, size: 22),
          title:
              Text(label, style: TextStyle(fontSize: 14, color: c.textPrimary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                Text(value!,
                    style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: c.textSecondary, size: 20),
            ],
          ),
          onTap: onTap,
          dense: true,
        ),
        if (showDivider)
          Divider(height: 0, indent: 56, color: c.border, thickness: 0.5),
      ],
    );
  }
}
