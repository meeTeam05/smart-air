import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_air/app_state.dart';
import 'package:smart_air/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final previousThemeMode = AppState.themeMode.value;
    addTearDown(() => AppState.themeMode.value = previousThemeMode);

    await tester.pumpWidget(const ProviderScope(child: SmartAirApp()));
    await tester.pump();

    final initialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(initialApp.themeMode, ThemeMode.light);

    AppState.themeMode.value = ThemeMode.dark;
    await tester.pump();

    final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(updatedApp.themeMode, ThemeMode.dark);
  });
}
