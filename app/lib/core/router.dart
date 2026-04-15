import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/homes/homes_screen.dart';
import '../screens/homes/home_detail_screen.dart';
import '../screens/homes/create_home_screen.dart';
import '../screens/provision/ble_scan_screen.dart';
import '../screens/provision/wifi_setup_screen.dart';
import '../screens/devices/device_dashboard_screen.dart';
import '../screens/devices/device_chart_screen.dart';
import '../screens/devices/command_history_screen.dart';
import '../screens/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/homes',
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // While session is being restored — don't redirect (prevents /login flash)
      if (authState.isLoading) return null;

      final loggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      final isPublic = loc == '/login' || loc == '/register';

      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && isPublic) return '/homes';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/homes', builder: (_, __) => const HomesScreen()),
      GoRoute(path: '/homes/create', builder: (_, __) => const CreateHomeScreen()),
      GoRoute(
        path: '/homes/:homeId',
        builder: (_, state) =>
            HomeDetailScreen(homeId: state.pathParameters['homeId']!),
      ),
      GoRoute(
        path: '/provision/scan',
        builder: (_, state) =>
            BleScanScreen(homeId: state.uri.queryParameters['homeId']!),
      ),
      GoRoute(
        path: '/provision/wifi',
        builder: (_, state) => WifiSetupScreen(
          homeId: state.uri.queryParameters['homeId']!,
          mac: state.uri.queryParameters['mac']!,
        ),
      ),
      GoRoute(
        path: '/devices/:id',
        builder: (_, state) =>
            DeviceDashboardScreen(deviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/devices/:id/chart',
        builder: (_, state) =>
            DeviceChartScreen(deviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/devices/:id/commands',
        builder: (_, state) =>
            CommandHistoryScreen(deviceId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
