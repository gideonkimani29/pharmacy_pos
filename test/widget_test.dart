import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/app.dart';
import 'package:pharmacy_pos/core/constants/app_strings.dart';

void main() {
  testWidgets('app requires sign-in before entering the POS', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PharmacyPosApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Pharmacy POS'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
