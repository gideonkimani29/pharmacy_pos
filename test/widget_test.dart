import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/app.dart';
import 'package:pharmacy_pos/core/constants/app_strings.dart';

void main() {
  testWidgets('app opens on the checkout screen with the demo catalog', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PharmacyPosApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(AppStrings.proceedToCheckout), findsOneWidget);
    expect(find.text('Panadol 500mg x24'), findsOneWidget);
  });
}
