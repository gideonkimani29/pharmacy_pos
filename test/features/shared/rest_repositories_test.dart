import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmacy_pos/core/network/api_session.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/payment.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/product.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/sale.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/sale_type.dart';
import 'package:pharmacy_pos/features/shared/data/rest_repositories.dart';

http.Response httpResponse(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

class _MemoryTokenStorage implements TokenStorage {
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
  test('product search maps API DTOs into domain products', () async {
    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenStorage: _MemoryTokenStorage(),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/products');
        expect(request.url.queryParameters, {'query': 'panadol'});
        return httpResponse([
          {
            'id': 'med-1',
            'sku': 'SKU-1',
            'barcode': '123',
            'name': 'Panadol',
            'genericName': 'Paracetamol',
            'unitPriceMinor': 1250,
            'sellableStock': 5,
            'lowStockThreshold': 2,
            'requiresPrescription': false,
            'nearestExpiry': '2027-01-01',
            'nextBatchNumber': 'LOT-1',
          }
        ]);
      }),
    );
    addTearDown(session.dispose);

    final result = await RestProductRepository(session).search('panadol');
    expect(result, isA<Ok<List<Product>>>());
    final products = (result as Ok<List<Product>>).value;
    expect(products.single.name, 'Panadol');
    expect(products.single.nearestExpiry, DateTime(2027));
    expect(products.single.nextBatchNumber, 'LOT-1');
  });

  test('sale submit forwards idempotency and maps receipt', () async {
    final session = ApiSession(
      baseUrl: 'http://localhost:8080/api/v1/',
      tokenStorage: _MemoryTokenStorage(),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/sales');
        expect(request.headers['idempotency-key'], 'cart-key');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedTotalMinor'], 2500);
        expect(body['payments'], [
          {'method': 'cash', 'amountMinor': 2600, 'reference': null}
        ]);
        return httpResponse({
          'receiptNumber': 'RCP-1',
          'totalMinor': 2500,
          'changeDueMinor': 100,
          'amountOnAccountMinor': 0,
          'completedAt': '2026-10-31T12:00:00Z',
        });
      }),
    );
    addTearDown(session.dispose);

    final result = await RestSaleRepository(session).submit(
      const SaleRequest(
        idempotencyKey: 'cart-key',
        saleType: SaleType.cash,
        customerId: null,
        lines: [
          SaleLine(
            productId: 'med-1',
            productName: 'Panadol',
            quantity: 2,
            unitPriceMinor: 1250,
            requiresPrescription: false,
          ),
        ],
        payments: [PaymentLine(method: PaymentMethod.cash, amountMinor: 2600)],
        prescriptionVerified: false,
        discountMinor: 0,
        expectedTotalMinor: 2500,
      ),
    );
    expect(result, isA<Ok<SaleReceipt>>());
    final receipt = (result as Ok<SaleReceipt>).value;
    expect(receipt.receiptNumber, 'RCP-1');
    expect(receipt.changeDueMinor, 100);
  });
}
