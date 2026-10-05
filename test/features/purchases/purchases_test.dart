import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/features/checkout/data/repositories/demo_product_repository.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/product.dart';
import 'package:pharmacy_pos/features/checkout/domain/usecases/search_products.dart';
import 'package:pharmacy_pos/features/purchases/data/repositories/demo_purchase_repository.dart';
import 'package:pharmacy_pos/features/purchases/data/repositories/demo_supplier_repository.dart';
import 'package:pharmacy_pos/features/purchases/domain/entities/purchase.dart';
import 'package:pharmacy_pos/features/purchases/domain/purchase_messages.dart';
import 'package:pharmacy_pos/features/purchases/domain/usecases/get_suppliers.dart';
import 'package:pharmacy_pos/features/purchases/domain/usecases/record_purchase.dart';
import 'package:pharmacy_pos/features/purchases/presentation/bloc/purchase_form_cubit.dart';

void main() {
  final received = DateTime(2026, 10, 4);

  PurchaseLine line({
    String product = 'p1',
    String batch = 'B1',
    DateTime? expiry,
    int quantity = 10,
    int cost = 1000,
    int price = 1500,
  }) {
    return PurchaseLine(
      productId: product,
      productName: 'Panadol',
      batchNumber: batch,
      expiryDate: expiry ?? DateTime(2027, 10, 4),
      quantity: quantity,
      unitCostMinor: cost,
      sellingPriceMinor: price,
    );
  }

  PurchaseRequest request({String? supplierId = 's1', String invoice = 'INV-1', List<PurchaseLine>? lines}) {
    return PurchaseRequest(
      idempotencyKey: 'k',
      supplierId: supplierId,
      invoiceNumber: invoice,
      receivedOn: received,
      paymentStatus: PurchasePaymentStatus.paid,
      lines: lines ?? [line()],
    );
  }

  group('RecordPurchase', () {
    final useCase = RecordPurchase(DemoPurchaseRepository());

    Future<String?> failureOf(PurchaseRequest r) async {
      final result = await useCase(r);
      return result is Err<Purchase> ? result.failure.message : null;
    }

    test('records a complete purchase and totals it', () async {
      final result = await useCase(request());
      expect(result, isA<Ok<Purchase>>());
      final purchase = (result as Ok<Purchase>).value;
      expect(purchase.totalMinor, 10000);
      expect(purchase.unitCount, 10);
      expect(purchase.lineCount, 1);
    });

    test('needs a supplier', () async {
      expect(await failureOf(request(supplierId: null)), PurchaseMessages.noSupplier);
    });

    test('needs an invoice number', () async {
      expect(await failureOf(request(invoice: '  ')), PurchaseMessages.noInvoice);
    });

    test('needs at least one line', () async {
      expect(await failureOf(request(lines: const [])), PurchaseMessages.noLines);
    });

    test('rejects an expiry on or before the received date', () async {
      expect(await failureOf(request(lines: [line(expiry: received)])), PurchaseMessages.expiryPast);
    });

    test('rejects a missing batch, zero cost and zero quantity', () async {
      expect(await failureOf(request(lines: [line(batch: ' ')])), PurchaseMessages.batchMissing);
      expect(await failureOf(request(lines: [line(cost: 0)])), PurchaseMessages.costInvalid);
      expect(await failureOf(request(lines: [line(quantity: 0)])), PurchaseMessages.quantityInvalid);
    });

    test('rejects the same batch twice for one product but allows it across products', () async {
      expect(
        await failureOf(request(lines: [line(batch: 'b1'), line(batch: 'B1')])),
        PurchaseMessages.duplicateBatch,
      );
      expect(await failureOf(request(lines: [line(product: 'p1'), line(product: 'p2')])), isNull);
    });
  });

  group('PurchaseFormCubit', () {
    const product = Product(
      id: 'p1',
      sku: 'PAR-500',
      barcode: '6161100010011',
      name: 'Panadol 500mg x24',
      genericName: 'Paracetamol',
      unitPriceMinor: 18000,
      sellableStock: 10,
      lowStockThreshold: 2,
      requiresPrescription: false,
    );

    PurchaseFormCubit build() => PurchaseFormCubit(
          getSuppliers: GetSuppliers(DemoSupplierRepository()),
          searchProducts: SearchProducts(DemoProductRepository()),
          recordPurchase: RecordPurchase(DemoPurchaseRepository()),
          clock: () => received,
        );

    test('adding a product starts a line at the current selling price', () {
      final cubit = build()..addProduct(product);
      expect(cubit.state.lines.single.sellingPriceMinor, 18000);
      expect(cubit.state.lines.single.quantity, 1);
      cubit.close();
    });

    test('the same product can be added twice, one line per batch', () {
      final cubit = build()
        ..addProduct(product)
        ..addProduct(product);
      expect(cubit.state.lines.length, 2);
      expect(cubit.state.lines[0].id, isNot(cubit.state.lines[1].id));
      cubit.close();
    });

    test('totals follow quantity and unit cost', () {
      final cubit = build()..addProduct(product);
      final id = cubit.state.lines.single.id;
      cubit.updateLine(id, (l) => l.copyWith(quantity: 5, unitCostMinor: 12000));
      expect(cubit.state.totalMinor, 60000);
      expect(cubit.state.unitCount, 5);
      cubit.removeLine(id);
      expect(cubit.state.totalMinor, 0);
      cubit.close();
    });

    test('an empty form reports the first problem instead of saving', () async {
      final cubit = build();
      await cubit.submit();
      expect(cubit.state.notice?.message, PurchaseMessages.noSupplier);
      expect(cubit.state.status, PurchaseFormStatus.editing);
      await cubit.close();
    });

    test('a complete form saves and exposes the purchase', () async {
      final cubit = build();
      await cubit.load();
      cubit
        ..setSupplier(DemoSupplierRepository.suppliers.first)
        ..setInvoiceNumber('INV-9')
        ..addProduct(product);
      final id = cubit.state.lines.single.id;
      cubit.updateLine(
        id,
        (l) => l.copyWith(
          batchNumber: 'B7',
          expiryDate: DateTime(2027, 12, 1),
          quantity: 20,
          unitCostMinor: 9000,
        ),
      );
      await cubit.submit();
      expect(cubit.state.status, PurchaseFormStatus.saved);
      expect(cubit.state.savedPurchase?.totalMinor, 180000);
      await cubit.close();
    });
  });
}
