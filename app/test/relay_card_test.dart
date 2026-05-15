import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/widgets/atoms/atmosphere_switch.dart';
import 'package:smart_air/widgets/atoms/relay_card.dart';

void main() {
  testWidgets('disabled relay card gates tap callbacks', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayCard(
            channel: 1,
            name: 'Fan',
            on: false,
            disabled: true,
            onTap: () => tapCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AtmosphereSwitch));
    await tester.pump();

    expect(tapCount, 0);
  });

  testWidgets('enabled relay card forwards tap callbacks', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayCard(
            channel: 1,
            name: 'Fan',
            on: true,
            onTap: () => tapCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AtmosphereSwitch));
    await tester.pump();

    expect(tapCount, 1);
  });
}
