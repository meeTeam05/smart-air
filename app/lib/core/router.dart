import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/homes/homes_screen.dart';
import '../screens/profile/home_detail_screen.dart';
import '../screens/homes/create_home_screen.dart';
import '../screens/provision/step1_power_on.dart';
import '../screens/provision/step2_ble_scan.dart';
import '../screens/provision/step3_wifi.dart';
import '../screens/provision/step4_cloud.dart';
import '../screens/provision/step5_name.dart';
import '../screens/devices/device_dashboard_screen.dart';
import '../screens/devices/command_history_screen.dart';
import '../screens/devices/settings/general_screen.dart';
import '../screens/devices/settings/calibration_wizard_screen.dart';
import '../screens/devices/settings/ota_screen.dart';
import '../widgets/shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // While session is being restored — don't redirect (prevents /login flash)
      if (authState.isLoading) return null;

      final loggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      final isPublic = loc == '/' || loc == '/login' || loc == '/register';

      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && isPublic && loc != '/') return '/home';
      return null;
    },
    routes: [
      // Splash route
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      
      // Auth routes (no shell)
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Shell routes (3 tabs with persistent bottom nav)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Home tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          // Notifications tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (_, __) => const NotificationsScreen(),
              ),
            ],
          ),
          // Profile tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Drill-down routes (outside shell, no bottom nav)
      GoRoute(path: '/homes', builder: (_, __) => const HomesScreen()),
      GoRoute(path: '/homes/create', builder: (_, __) => const CreateHomeScreen()),
      GoRoute(
        path: '/homes/:homeId',
        builder: (_, state) =>
            HomeDetailScreen(homeId: state.pathParameters['homeId']!),
      ),
      GoRoute(
        path: '/provision',
        builder: (_, state) => Step1PowerOnScreen(
          homeId: state.uri.queryParameters['homeId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/provision/scan',
        builder: (_, state) => Step2BleScanScreen(
          homeId: state.uri.queryParameters['homeId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/provision/wifi',
        builder: (_, state) => Step3WifiScreen(
          homeId: state.uri.queryParameters['homeId'] ?? '',
          mac: state.uri.queryParameters['mac'] ?? '',
          deviceId: state.uri.queryParameters['deviceId'] ??
              state.uri.queryParameters['mac'] ?? '',
          ssid: state.uri.queryParameters['ssid'],
        ),
      ),
      GoRoute(
        path: '/provision/announce',
        builder: (_, state) => Step4CloudScreen(
          homeId: state.uri.queryParameters['homeId'] ?? '',
          mac: state.uri.queryParameters['mac'] ?? '',
          deviceId: state.uri.queryParameters['deviceId'] ??
              state.uri.queryParameters['mac'] ?? '',
        ),
      ),
      GoRoute(
        path: '/provision/name',
        builder: (_, state) => Step5NameScreen(
          homeId: state.uri.queryParameters['homeId'] ?? '',
          mac: state.uri.queryParameters['mac'] ?? '',
          deviceId: state.uri.queryParameters['deviceId'] ??
              state.uri.queryParameters['mac'] ?? '',
        ),
      ),
      GoRoute(
        path: '/devices/:id',
        builder: (_, state) =>
            DeviceDashboardScreen(deviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/devices/:id/commands',
        builder: (_, state) =>
            CommandHistoryScreen(deviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/devices/:id/settings',
        builder: (_, state) =>
            GeneralSettingsScreen(deviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/devices/:id/calibrate/:sensor',
        builder: (_, state) => CalibrationWizardScreen(
          deviceId: state.pathParameters['id']!,
          sensor: state.pathParameters['sensor']!,
        ),
      ),
      GoRoute(
        path: '/devices/:id/ota',
        builder: (_, state) =>
            OtaScreen(deviceId: state.pathParameters['id']!),
      ),
      // Profile home detail route
      GoRoute(
        path: '/profile/home/:homeId',
        builder: (_, state) =>
            HomeDetailScreen(homeId: state.pathParameters['homeId']!),
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
