import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'atmosphere_bottom_nav.dart';

/// App shell with persistent bottom navigation.
/// Wraps the 4 tab screens (Home, Automation, Notifications, Profile).
/// Used by GoRouter ShellRoute to provide consistent navigation chrome.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey(navigationShell.currentIndex),
        tween: Tween(begin: 0, end: 1),
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: navigationShell,
        builder: (context, opacity, child) => Opacity(
          opacity: opacity,
          child: child,
        ),
      ),
      bottomNavigationBar: AtmosphereBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
