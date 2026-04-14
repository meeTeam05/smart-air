import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'app_state.dart';
import 'core/router.dart';

void main() => runApp(const ProviderScope(child: SmartAirApp()));

class SmartAirApp extends ConsumerStatefulWidget {
  const SmartAirApp({super.key});

  @override
  ConsumerState<SmartAirApp> createState() => _SmartAirAppState();
}

class _SmartAirAppState extends ConsumerState<SmartAirApp> {
  @override
  void initState() {
    super.initState();
    AppState.themeMode.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    AppState.themeMode.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Smart Air',
      themeMode: AppState.themeMode.value,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
