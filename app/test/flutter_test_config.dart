import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      // Try to load fonts, but don't fail if unavailable (headless environment)
      try {
        await loadAppFonts();
      } catch (e) {
        // Font loading failed - tests will use fallback fonts
        // This is expected in headless environments without network access
        TestWidgetsFlutterBinding.ensureInitialized();
      }
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // Skip golden assertions in environments where font loading fails
      skipGoldenAssertion: () => const bool.fromEnvironment('SKIP_GOLDENS', defaultValue: false),
      enableRealShadows: true,
    ),
  );
}
