import 'package:equatable/equatable.dart';

enum PurchasePaymentStatus { paid, onCredit }

/// One received batch. Recording a purchase creates a stock batch per line.
class PurchaseLine extends Equatable {
  const PurchaseLine({
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.unitCostMinor,
    required this.sellingPriceMinor,
  });

  final String productId;
  final String productName;
  final String batchNumber;
  final DateTime? expiryDate;
  final int quantity;
  final int unitCostMinor;
  final int sellingPriceMinor;

  int get lineTotalMinor => unitCostMinor * quantity;

  @override
  List<Object?> get props => [
        productId,
        productName,
        batchNumber,
        expiryDate,
        quantity,
        unitCostMinor,
        sellingPriceMinor,
      ];
}

class PurchaseRequest extends Equatable {
  const PurchaseRequest({
    required this.idempotencyKey,
    required this.supplierId,
    required this.invoiceNumber,
    required this.receivedOn,
    required this.paymentStatus,
    required this.lines,
  });

  final String idempotencyKey;
  final String? supplierId;
  final String invoiceNumber;
  final DateTime receivedOn;
  final PurchasePaymentStatus paymentStatus;
  final List<PurchaseLine> lines;

  int get totalMinor => lines.fold(0, (sum, line) => sum + line.lineTotalMinor);
  int get unitCount => lines.fold(0, (sum, line) => sum + line.quantity);

  @override
  List<Object?> get props => [idempotencyKey, supplierId, invoiceNumber, receivedOn, paymentStatus, lines];
}

class Purchase extends Equatable {
  const Purchase({
    required this.id,
    required this.reference,
    required this.supplierName,
    required this.invoiceNumber,
    required this.receivedOn,
    required this.paymentStatus,
    required this.lineCount,
    required this.unitCount,
    required this.totalMinor,
  });

  final String id;
  final String reference;
  final String supplierName;
  final String invoiceNumber;
  final DateTime receivedOn;
  final PurchasePaymentStatus paymentStatus;
  final int lineCount;
  final int unitCount;
  final int totalMinor;

  @override
  List<Object?> get props => [
        id,
        reference,
        supplierName,
        invoiceNumber,
        receivedOn,
        paymentStatus,
        lineCount,
        unitCount,
        totalMinor,
      ];
}
