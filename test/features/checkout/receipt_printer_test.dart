import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/cart_item.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/product.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/sale.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/sale_type.dart';
import 'package:pharmacy_pos/features/checkout/presentation/bloc/cart_bloc.dart';
import 'package:pharmacy_pos/features/checkout/presentation/receipt_printer.dart';
import 'package:pharmacy_pos/features/settings/domain/entities/app_settings.dart';

void main() {
  test('builds a receipt PDF with the configured copies and paper width',
      () async {
    final settings = _settings(copies: 2);
    final pdf = await ReceiptPrinter.buildPdf(
      settings: settings,
      cart: _cart(),
      receipt: _receipt,
    );

    expect(utf8.decode(pdf.take(8).toList()), startsWith('%PDF-'));
    expect(pdf.length, greaterThan(1000));
  });

  test('rejects a receipt copy count outside the supported range', () async {
    await expectLater(
      () => ReceiptPrinter.buildPdf(
        settings: _settings(copies: 0),
        cart: _cart(),
        receipt: _receipt,
      ),
      throwsRangeError,
    );
  });
}

AppSettings _settings({required int copies}) => AppSettings(
      pharmacyName: 'Test Pharmacy',
      branchName: 'Main',
      address: '1 Market Street',
      phone: '0700000000',
      email: 'test@example.com',
      taxPin: 'A123456789B',
      licenceNumber: 'PPB-123',
      taxRateBasisPoints: 1600,
      maxCashierDiscountPercent: 5,
      allowCreditSales: true,
      printerConnection: PrinterConnection.usb,
      paperWidth: PaperWidth.mm58,
      autoPrintReceipt: true,
      receiptCopies: copies,
      printPharmacyDetails: true,
      receiptFooter: 'Thank you.',
    );

CartState _cart() {
  const product = Product(
    id: 'product-1',
    sku: 'SKU-1',
    barcode: '12345',
    name: 'Paracetamol 500 mg',
    genericName: 'Paracetamol',
    unitPriceMinor: 1250,
    sellableStock: 20,
    lowStockThreshold: 5,
    requiresPrescription: false,
  );
  return CartState(
    items: const [CartItem(product: product, quantity: 2)],
    status: CartStatus.completed,
    prescriptionVerified: false,
    idempotencyKey: 'sale-1',
    saleType: SaleType.cash,
    discountMinor: 100,
    taxRateBasisPoints: 1600,
  );
}

final _receipt = SaleReceipt(
  receiptNumber: 'R-100',
  totalMinor: 2800,
  changeDueMinor: 0,
  amountOnAccountMinor: 0,
  completedAt: DateTime(2026, 10, 31, 14),
);
