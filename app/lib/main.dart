import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'app_state.dart';
import 'core/router.dart';
import 'core/env.dart';
import 'providers/auth_provider.dart';
import 'providers/devices_provider.dart';

void main() {
  // Disable runtime font fetching - all fonts must be bundled
  GoogleFonts.config.allowRuntimeFetching = false;
  Env.validate();
  
  if (kIsWeb) {
    runApp(const _WebUnsupportedApp());
  } else {
    runApp(const ProviderScope(child: SmartAirApp()));
  }
}

class SmartAirApp extends ConsumerStatefulWidget {
  const SmartAirApp({super.key});

  @override
  ConsumerState<SmartAirApp> createState() => _SmartAirAppState();
}

class _SmartAirAppState extends ConsumerState<SmartAirApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ref.read(authProvider).valueOrNull == null) return;
    ref.read(devicesProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeMode,
      builder: (context, themeMode, _) => MaterialApp.router(
        title: 'Atmosphere',
        themeMode: themeMode,
        theme: AtmosphereTheme.light(),
        darkTheme: AtmosphereTheme.dark(),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    );
  }
}

class _WebUnsupportedApp extends StatelessWidget {
  const _WebUnsupportedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atmosphere',
      theme: AtmosphereTheme.light(),
      darkTheme: AtmosphereTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_android, size: 64, color: Colors.grey),
                SizedBox(height: 24),
                Text(
                  'Web Not Supported',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Smart Air requires Android or iOS.\nProvisioning flow uses Bluetooth Low Energy, which is not available on web.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
