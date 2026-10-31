import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/money.dart';
import '../../settings/domain/entities/app_settings.dart';
import '../domain/entities/sale.dart';
import 'bloc/cart_bloc.dart';

abstract final class ReceiptPrinter {
  static Future<bool> printReceipt({
    required AppSettings settings,
    required CartState cart,
    required SaleReceipt receipt,
  }) {
    _validateSettings(settings);
    final format = _pageFormat(settings.paperWidth);
    return Printing.layoutPdf(
      name: 'Receipt ${receipt.receiptNumber}',
      format: format,
      dynamicLayout: false,
      onLayout: (_) => buildPdf(
        settings: settings,
        cart: cart,
        receipt: receipt,
      ),
    );
  }

  static Future<Uint8List> buildPdf({
    required AppSettings settings,
    required CartState cart,
    required SaleReceipt receipt,
  }) async {
    _validateSettings(settings);
    final format = _pageFormat(settings.paperWidth);
    final document = pw.Document();
    for (var copy = 0; copy < settings.receiptCopies; copy++) {
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(3 * PdfPageFormat.mm),
          build: (_) => _receiptPage(settings, cart, receipt),
        ),
      );
    }
    return document.save();
  }

  static void _validateSettings(AppSettings settings) {
    if (settings.receiptCopies < 1 || settings.receiptCopies > 5) {
      throw RangeError.range(settings.receiptCopies, 1, 5, 'receiptCopies');
    }
  }

  static PdfPageFormat _pageFormat(PaperWidth width) {
    final millimeters = width == PaperWidth.mm58 ? 58.0 : 80.0;
    return PdfPageFormat(millimeters * PdfPageFormat.mm, double.infinity);
  }

  static pw.Widget _receiptPage(
    AppSettings settings,
    CartState cart,
    SaleReceipt receipt,
  ) {
    final details = <String>[
      settings.branchName,
      settings.address,
      settings.phone,
      settings.email,
      if (settings.taxPin.isNotEmpty) 'KRA PIN: ${settings.taxPin}',
      if (settings.licenceNumber.isNotEmpty)
        'Licence: ${settings.licenceNumber}',
    ].where((value) => value.trim().isNotEmpty);
    final date = receipt.completedAt.toLocal();
    final timestamp =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (settings.printPharmacyDetails) ...[
          if (settings.pharmacyName.isNotEmpty)
            pw.Text(
              settings.pharmacyName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          for (final line in details)
            pw.Text(line,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8)),
        ],
        pw.SizedBox(height: 6),
        pw.Divider(),
        _receiptRow('Receipt', receipt.receiptNumber),
        _receiptRow('Date', timestamp),
        _receiptRow('Sale type', cart.saleType.name.toUpperCase()),
        if (cart.customer != null) _receiptRow('Customer', cart.customer!.name),
        pw.Divider(),
        for (final item in cart.items) ...[
          pw.Text(item.product.name,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          _receiptRow(
            '${item.quantity} x ${Money.format(item.product.unitPriceMinor)}',
            Money.format(item.lineTotalMinor),
          ),
          pw.SizedBox(height: 3),
        ],
        pw.Divider(),
        _receiptRow('Subtotal', Money.format(cart.totals.subtotalMinor)),
        if (cart.totals.discountMinor > 0)
          _receiptRow(
              'Discount', '-${Money.format(cart.totals.discountMinor)}'),
        _receiptRow(
          'Tax (${(cart.taxRateBasisPoints / 100).toStringAsFixed(2)}%)',
          Money.format(cart.totals.taxMinor),
        ),
        _receiptRow(
          'TOTAL',
          Money.format(receipt.totalMinor),
          bold: true,
        ),
        if (receipt.changeDueMinor > 0)
          _receiptRow('Change', Money.format(receipt.changeDueMinor)),
        if (receipt.amountOnAccountMinor > 0)
          _receiptRow('On account', Money.format(receipt.amountOnAccountMinor)),
        if (settings.receiptFooter.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(settings.receiptFooter.trim(),
              textAlign: pw.TextAlign.center),
        ],
      ],
    );
  }

  static pw.Widget _receiptRow(String label, String value,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: style, textAlign: pw.TextAlign.right),
        ],
      ),
    );
  }
}
