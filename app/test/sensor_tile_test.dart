import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/app_theme.dart';
import 'package:smart_air/widgets/atoms/sensor_tile.dart';

void main() {
  testWidgets('scales long values instead of overflowing in narrow tiles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AtmosphereTheme.light(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: SensorTile(
                label: 'CO',
                value: '5000.00',
                unit: 'ppm',
                icon: Icons.air,
                tone: SensorTone.cool,
                sparkColor: Colors.green,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('5000.00'), findsOneWidget);
    expect(find.text('ppm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
