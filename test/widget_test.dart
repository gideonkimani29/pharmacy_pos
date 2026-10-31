import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pharmacy_pos/app.dart';
import 'package:pharmacy_pos/core/network/api_session.dart';

class _EmptyTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {}
}

void main() {
  testWidgets('app requires sign-in before entering the POS', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenStorage: _EmptyTokenStorage(),
      client: MockClient((_) async => throw StateError('No request expected')),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(PharmacyPosApp(session: session));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sign in to Pharmacy POS'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
