import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/features/checkout/data/repositories/demo_sale_repository.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/payment.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/product.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/sale.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/sale_type.dart';
import 'package:pharmacy_pos/features/checkout/domain/usecases/submit_sale.dart';
import 'package:pharmacy_pos/features/checkout/presentation/bloc/cart_bloc.dart';

void main() {
  final now = DateTime(2026, 10, 3);

  Product product({
    String id = 'p1',
    int price = 10000,
    int stock = 5,
    bool rx = false,
    DateTime? expiry,
  }) {
    return Product(
      id: id,
      sku: 'SKU-$id',
      barcode: '616110001$id',
      name: 'Product $id',
      genericName: 'Generic $id',
      unitPriceMinor: price,
      sellableStock: stock,
      lowStockThreshold: 2,
      requiresPrescription: rx,
      nearestExpiry: expiry ?? DateTime(2027, 10, 3),
    );
  }

  CartBloc buildBloc() => CartBloc(submitSale: SubmitSale(DemoSaleRepository()), clock: () => now);

  group('CartBloc', () {
    test('adding the same product increments quantity', () async {
      final bloc = buildBloc();
      final p = product();
      bloc
        ..add(CartProductAdded(p))
        ..add(CartProductAdded(p));
      await bloc.stream.firstWhere((s) => s.unitCount == 2);
      expect(bloc.state.items.single.quantity, 2);
      expect(bloc.state.totals.totalMinor, 20000);
      await bloc.close();
    });

    test('quantity is capped at sellable stock and raises a notice', () async {
      final bloc = buildBloc();
      final p = product(stock: 1);
      bloc
        ..add(CartProductAdded(p))
        ..add(CartProductAdded(p));
      await bloc.stream.firstWhere((s) => s.notice != null);
      expect(bloc.state.unitCount, 1);
      await bloc.close();
    });

    test('out-of-stock product is rejected', () async {
      final bloc = buildBloc()..add(CartProductAdded(product(stock: 0)));
      await bloc.stream.firstWhere((s) => s.notice != null);
      expect(bloc.state.isEmpty, isTrue);
      await bloc.close();
    });

    test('Rx item blocks checkout until verified', () async {
      final bloc = buildBloc()..add(CartProductAdded(product(rx: true)));
      await bloc.stream.firstWhere((s) => !s.isEmpty);
      expect(bloc.state.canCheckout, isFalse);
      bloc.add(const CartPrescriptionToggled(verified: true));
      await bloc.stream.firstWhere((s) => s.prescriptionVerified);
      expect(bloc.state.canCheckout, isTrue);
      await bloc.close();
    });

    test('checkout with cash completes and reports change', () async {
      final bloc = buildBloc()..add(CartProductAdded(product()));
      await bloc.stream.firstWhere((s) => !s.isEmpty);
      bloc.add(const CartCheckoutSubmitted([PaymentLine(method: PaymentMethod.cash, amountMinor: 15000)]));
      final done = await bloc.stream.firstWhere((s) => s.status == CartStatus.completed);
      expect(done.receipt?.changeDueMinor, 5000);
      await bloc.close();
    });

    test('changing the cart issues a fresh idempotency key', () async {
      final bloc = buildBloc();
      final initialKey = bloc.state.idempotencyKey;
      bloc.add(CartProductAdded(product()));
      await bloc.stream.firstWhere((s) => !s.isEmpty);
      expect(bloc.state.idempotencyKey, isNot(initialKey));
      await bloc.close();
    });
  });

  group('SubmitSale validation', () {
    final useCase = SubmitSale(DemoSaleRepository());
    const line = SaleLine(
      productId: 'p1',
      productName: 'Product',
      quantity: 1,
      unitPriceMinor: 10000,
      requiresPrescription: false,
    );

    SaleRequest request(List<PaymentLine> payments) => SaleRequest(
          idempotencyKey: 'k',
          saleType: SaleType.cash,
          lines: const [line],
          payments: payments,
          prescriptionVerified: false,
          discountMinor: 0,
          expectedTotalMinor: 10000,
        );

    test('rejects underpayment', () async {
      final result = await useCase(request(const [PaymentLine(method: PaymentMethod.cash, amountMinor: 5000)]));
      expect(result, isA<Err<SaleReceipt>>());
    });

    test('rejects non-cash overpayment', () async {
      final result = await useCase(request(const [
        PaymentLine(method: PaymentMethod.mobile, amountMinor: 12000, reference: 'QGH7XYZ123'),
      ]));
      expect(result, isA<Err<SaleReceipt>>());
    });

    test('credit sale needs a customer', () async {
      const credit = SaleRequest(
        idempotencyKey: 'k',
        saleType: SaleType.credit,
        lines: [line],
        payments: [],
        prescriptionVerified: false,
        discountMinor: 0,
        expectedTotalMinor: 10000,
      );
      expect(await useCase(credit), isA<Err<SaleReceipt>>());
    });

    test('credit sale with a customer goes on account', () async {
      const credit = SaleRequest(
        idempotencyKey: 'k2',
        saleType: SaleType.credit,
        customerId: 'c1',
        lines: [line],
        payments: [],
        prescriptionVerified: false,
        discountMinor: 0,
        expectedTotalMinor: 10000,
      );
      final result = await useCase(credit);
      expect(result, isA<Ok<SaleReceipt>>());
      expect((result as Ok<SaleReceipt>).value.amountOnAccountMinor, 10000);
    });

    test('discount reduces the amount that must be paid', () async {
      const discounted = SaleRequest(
        idempotencyKey: 'k3',
        saleType: SaleType.cash,
        lines: [line],
        payments: [PaymentLine(method: PaymentMethod.cash, amountMinor: 8000)],
        prescriptionVerified: false,
        discountMinor: 2000,
        expectedTotalMinor: 8000,
      );
      expect(await useCase(discounted), isA<Ok<SaleReceipt>>());
    });

    test('discount larger than the subtotal is rejected', () async {
      const bad = SaleRequest(
        idempotencyKey: 'k4',
        saleType: SaleType.cash,
        lines: [line],
        payments: [PaymentLine(method: PaymentMethod.cash, amountMinor: 10000)],
        prescriptionVerified: false,
        discountMinor: 20000,
        expectedTotalMinor: 0,
      );
      expect(await useCase(bad), isA<Err<SaleReceipt>>());
    });

    test('accepts split tender that covers the total', () async {
      final result = await useCase(request(const [
        PaymentLine(method: PaymentMethod.mobile, amountMinor: 6000, reference: 'QGH7XYZ123'),
        PaymentLine(method: PaymentMethod.cash, amountMinor: 5000),
      ]));
      expect(result, isA<Ok<SaleReceipt>>());
    });
  });
}
