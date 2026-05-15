import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Bottom navigation bar with pill-style active indicator.
/// Matches Atmosphere mockup design with brandTint2 pill background behind active icon.
class AtmosphereBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AtmosphereBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animationDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 250);
    // Read system bottom inset (navigation bar height) and add it explicitly
    // so the Container has a fixed, correct total height without overflow.
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 72 + bottomPadding,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: AppIcons.home,
              label: 'Home',
              active: currentIndex == 0,
              duration: animationDuration,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: AppIcons.automation,
              label: 'Automation',
              active: currentIndex == 1,
              duration: animationDuration,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: AppIcons.notifications,
              label: 'Notifications',
              active: currentIndex == 2,
              duration: animationDuration,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: AppIcons.profile,
              label: 'Profile',
              active: currentIndex == 3,
              duration: animationDuration,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Duration duration;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: '$label tab',
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 48,
                child: Center(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeInOut,
                    width: 56,
                    height: 32,
                    decoration: BoxDecoration(
                      color: active
                          ? AtmosphereTokens.brandTint2
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AtmosphereTokens.radiusPill),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: active ? AppColors.primary : c.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppColors.primary : c.textSecondary,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
