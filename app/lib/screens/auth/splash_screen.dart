import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/palette.dart';
import '../../design/text_styles.dart';
import '../../widgets/atoms/dot_logo.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authState = ref.watch(authProvider);

    if (!authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(authState.valueOrNull != null ? '/home' : '/login');
      });
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AtmosphereDotLogo(
              size: 80,
              color: c.brand,
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Air',
              style: AtmosphereTextStyles.h2(c.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Indoor Air Quality Monitor',
              style: AtmosphereTextStyles.body(c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
