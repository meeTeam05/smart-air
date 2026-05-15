import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../atoms/dot_logo.dart';

/// AppBar with 3 variants: brand, back, minimal.
/// - brand: DotLogo + "Atmosphere" wordmark left, avatar right
/// - back: back arrow + title left, optional action icons right
/// - minimal: used in BLE wizard (no nav)
class AtmosphereAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AtmosphereAppBarVariant variant;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const AtmosphereAppBar.brand({
    super.key,
    this.actions,
  })  : variant = AtmosphereAppBarVariant.brand,
        title = null,
        onBack = null;

  const AtmosphereAppBar.back({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
  }) : variant = AtmosphereAppBarVariant.back;

  const AtmosphereAppBar.minimal({
    super.key,
    this.title,
  })  : variant = AtmosphereAppBarVariant.minimal,
        actions = null,
        onBack = null;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    switch (variant) {
      case AtmosphereAppBarVariant.brand:
        return _buildBrandBar(context, c);
      case AtmosphereAppBarVariant.back:
        return _buildBackBar(context, c);
      case AtmosphereAppBarVariant.minimal:
        return _buildMinimalBar(context, c);
    }
  }

  Widget _buildBrandBar(BuildContext context, AtmospherePalette c) {
    return AppBar(
      backgroundColor: c.bg,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AtmosphereDotLogo(size: 24, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'Atmosphere',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
      actions: actions ??
          [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AtmosphereTokens.brandTint,
              child: Icon(AppIcons.profile, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
          ],
    );
  }

  Widget _buildBackBar(BuildContext context, AtmospherePalette c) {
    return AppBar(
      backgroundColor: c.bg,
      elevation: 0,
      leading: IconButton(
        icon: Icon(AppIcons.back, color: c.textPrimary),
        onPressed: onBack ?? () => Navigator.of(context).pop(),
      ),
      title: Text(
        title ?? '',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      actions: actions,
    );
  }

  Widget _buildMinimalBar(BuildContext context, AtmospherePalette c) {
    return AppBar(
      backgroundColor: c.bg,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: title != null
          ? Text(
              title!,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            )
          : null,
    );
  }
}

enum AtmosphereAppBarVariant {
  brand,
  back,
  minimal,
}
