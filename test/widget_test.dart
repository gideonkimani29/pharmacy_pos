import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmacy_pos/app.dart';
import 'package:pharmacy_pos/core/network/api_session.dart';

class _EmptyTokenStorage implements TokenStorage {
  _EmptyTokenStorage({this.accessToken, this.refreshToken});

  final String? accessToken;
  final String? refreshToken;

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens(
      {required String accessToken, required String refreshToken}) async {}
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

  testWidgets('invitation acceptance sets a password and returns to sign-in',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    http.Request? acceptedRequest;
    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenStorage: _EmptyTokenStorage(),
      client: MockClient((request) async {
        acceptedRequest = request;
        return http.Response('', 200);
      }),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(PharmacyPosApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Have an invitation token?'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'invite-token');
    await tester.enterText(fields.at(1), 'a-very-long-password');
    await tester.enterText(fields.at(2), 'a-very-long-password');
    await tester.tap(find.text('Set password'));
    await tester.pumpAndSettle();

    expect(find.text('Password set. You can now sign in.'), findsOneWidget);
    expect(acceptedRequest?.url.path, '/api/v1/auth/accept-invitation');
    expect(
      jsonDecode(acceptedRequest!.body),
      {'token': 'invite-token', 'password': 'a-very-long-password'},
    );
    expect(find.text('Sign in to Pharmacy POS'), findsOneWidget);
  });

  testWidgets('authenticated app provides the listenable API session safely',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenStorage:
          _EmptyTokenStorage(accessToken: 'expired', refreshToken: 'refresh'),
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          return http.Response(
            jsonEncode({
              'accessToken': 'access',
              'refreshToken': 'rotated',
              'tokenType': 'Bearer',
              'expiresIn': 900,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/settings') {
          return http.Response(
            jsonEncode({'taxRateBasisPoints': 0}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'not_found',
              'message': 'Not configured.',
              'details': null
            }
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(PharmacyPosApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Pharmacy POS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
