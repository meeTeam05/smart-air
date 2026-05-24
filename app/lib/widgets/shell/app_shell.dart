import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'atmosphere_bottom_nav.dart';

/// App shell with persistent bottom navigation.
/// Wraps the 3 tab screens (Home, Notifications, Profile).
/// Used by GoRouter ShellRoute to provide consistent navigation chrome.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
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
