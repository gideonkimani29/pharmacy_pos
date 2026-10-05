import 'package:equatable/equatable.dart';

import 'payment.dart';
import 'sale_type.dart';

class SaleLine extends Equatable {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.requiresPrescription,
  });

  final String productId;
  final String productName;
  final int quantity;
  final int unitPriceMinor;
  final bool requiresPrescription;

  int get lineTotalMinor => unitPriceMinor * quantity;

  @override
  List<Object?> get props => [productId, productName, quantity, unitPriceMinor, requiresPrescription];
}

class SaleRequest extends Equatable {
  const SaleRequest({
    required this.idempotencyKey,
    required this.saleType,
    required this.lines,
    required this.payments,
    required this.prescriptionVerified,
    required this.discountMinor,
    required this.expectedTotalMinor,
    this.customerId,
  });

  final String idempotencyKey;
  final SaleType saleType;
  final String? customerId;
  final List<SaleLine> lines;

  /// Empty is valid for a credit sale (everything goes on account).
  final List<PaymentLine> payments;
  final bool prescriptionVerified;
  final int discountMinor;

  /// Total the cashier saw. The backend rejects the sale if prices drifted.
  final int expectedTotalMinor;

  int get subtotalMinor => lines.fold(0, (sum, line) => sum + line.lineTotalMinor);

  @override
  List<Object?> get props => [
        idempotencyKey,
        saleType,
        customerId,
        lines,
        payments,
        prescriptionVerified,
        discountMinor,
        expectedTotalMinor,
      ];
}

class SaleReceipt extends Equatable {
  const SaleReceipt({
    required this.receiptNumber,
    required this.totalMinor,
    required this.changeDueMinor,
    required this.amountOnAccountMinor,
    required this.completedAt,
  });

  final String receiptNumber;
  final int totalMinor;
  final int changeDueMinor;
  final int amountOnAccountMinor;
  final DateTime completedAt;

  @override
  List<Object?> get props => [receiptNumber, totalMinor, changeDueMinor, amountOnAccountMinor, completedAt];
}
