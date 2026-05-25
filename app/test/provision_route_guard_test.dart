import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/screens/provision/step4_cloud.dart';
import 'package:smart_air/screens/provision/step5_name.dart';

void main() {
  testWidgets('step4 cloud shows invalid-state UI for missing query params',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Step4CloudScreen(
            homeId: '',
            mac: '',
            deviceId: '',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Missing provisioning details'), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step5 name shows invalid-state UI for missing query params',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Step5NameScreen(
            homeId: '',
            mac: '',
            deviceId: '',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Missing provisioning details'), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
