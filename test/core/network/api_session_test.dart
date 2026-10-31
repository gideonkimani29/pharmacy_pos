import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmacy_pos/core/network/api_session.dart';

class _MemoryTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}

http.Response _tokens(String access, String refresh) => http.Response(
      jsonEncode({
        'accessToken': access,
        'refreshToken': refresh,
        'tokenType': 'Bearer',
        'expiresIn': 900,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('login persists tokens and forwards bearer and idempotency headers', () async {
    final storage = _MemoryTokenStorage();
    final requests = <http.Request>[];
    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenStorage: storage,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/auth/login') {
          expect(jsonDecode(request.body), {'email': 'cashier@example.test', 'password': 'secret'});
          return _tokens('access-1', 'refresh-1');
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'medicine-1',
              'sku': 'SKU-1',
              'barcode': '',
              'name': 'Medicine',
              'genericName': '',
              'unitPriceMinor': 100,
              'sellableStock': 5,
              'lowStockThreshold': 2,
              'requiresPrescription': false,
              'nearestExpiry': null,
              'nextBatchNumber': null,
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(session.dispose);

    await session.login(email: ' cashier@example.test ', password: 'secret');
    expect(session.isAuthenticated, isTrue);
    expect(storage.accessToken, 'access-1');
    expect(storage.refreshToken, 'refresh-1');

    await session.post('sales', idempotencyKey: 'key-1', body: {'saleType': 'cash'});
    expect(requests.last.headers['authorization'], 'Bearer access-1');
    expect(requests.last.headers['idempotency-key'], 'key-1');
  });

  test('expired access token refreshes and retries the original request once', () async {
    final storage = _MemoryTokenStorage()
      ..accessToken = 'expired'
      ..refreshToken = 'refresh-old';
    var refreshCount = 0;
    var productCount = 0;
    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1/',
      tokenStorage: storage,
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCount++;
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          if (refreshCount == 1) {
            expect(data, {'refreshToken': 'refresh-old'});
            return _tokens('access-stale', 'refresh-middle');
          }
          expect(data, {'refreshToken': 'refresh-middle'});
          return _tokens('access-new', 'refresh-new');
        }
        if (request.url.path == '/api/v1/products') {
          productCount++;
          if (request.headers['authorization'] == 'Bearer access-stale') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'unauthorized', 'message': 'Expired', 'details': null}
              }),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        throw StateError('Unexpected URL ${request.url}');
      }),
    );
    addTearDown(session.dispose);

    await session.restore();
    expect(session.isAuthenticated, isTrue);
    await session.get('products');
    expect(refreshCount, 2);
    expect(productCount, 2);
    expect(storage.accessToken, 'access-new');
    expect(storage.refreshToken, 'refresh-new');
  });

  test('failed refresh clears persisted credentials', () async {
    final storage = _MemoryTokenStorage()
      ..accessToken = 'old-access'
      ..refreshToken = 'revoked';
    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenStorage: storage,
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'error': {'code': 'invalid_refresh_token', 'message': 'Expired', 'details': null}
            }),
            401,
            headers: {'content-type': 'application/json'},
          )),
    );
    addTearDown(session.dispose);

    await session.restore();
    expect(session.isInitialized, isTrue);
    expect(session.isAuthenticated, isFalse);
    expect(storage.refreshToken, isNull);
  });
}
