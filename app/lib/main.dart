import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/automation_screen.dart';
import 'screens/profile_screen.dart';

void main() => runApp(const SmartAirApp());

class SmartAirApp extends StatefulWidget {
  const SmartAirApp({super.key});

  @override
  State<SmartAirApp> createState() => _SmartAirAppState();
}

class _SmartAirAppState extends State<SmartAirApp> {
  @override
  void initState() {
    super.initState();
    // Rebuild whenever theme changes.
    AppState.themeMode.addListener(_onStateChange);
  }

  @override
  void dispose() {
    AppState.themeMode.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MT Home',
      themeMode: AppState.themeMode.value,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const NavShell(),
    );
  }
}

class NavShell extends StatefulWidget {
  const NavShell({super.key});

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  int _idx = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    AutomationScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Automation',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
