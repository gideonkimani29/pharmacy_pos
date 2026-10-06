import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_config.dart';

enum BatchExpiry { expired, within30, within60, within90, ok }

enum StockAdjustmentReason { expired, damaged, returnedToSupplier, countCorrection, other }

/// One received batch of one medicine. FEFO sells the earliest-expiring
/// batch that still has stock and has not expired.
class StockBatch extends Equatable {
  const StockBatch({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.supplierName,
    required this.receivedOn,
    required this.expiryDate,
    required this.quantityReceived,
    required this.quantityOnHand,
    required this.unitCostMinor,
    required this.sellingPriceMinor,
    required this.reorderLevel,
  });

  final String id;
  final String medicineId;
  final String medicineName;
  final String batchNumber;
  final String supplierName;
  final DateTime receivedOn;
  final DateTime expiryDate;
  final int quantityReceived;
  final int quantityOnHand;
  final int unitCostMinor;
  final int sellingPriceMinor;

  /// The medicine's reorder level, joined in by the API for the summary view.
  final int reorderLevel;

  bool get isDepleted => quantityOnHand <= 0;
  int get valueAtCostMinor => unitCostMinor * quantityOnHand;

  /// Compares dates only: a batch is sellable through its expiry date.
  BatchExpiry expiryAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (expiryDate.isBefore(today)) return BatchExpiry.expired;
    final days = expiryDate.difference(today).inDays;
    if (days <= AppConfig.expiryCriticalDays) return BatchExpiry.within30;
    if (days <= AppConfig.expiryWarningDays) return BatchExpiry.within60;
    if (days <= AppConfig.expiryNoticeDays) return BatchExpiry.within90;
    return BatchExpiry.ok;
  }

  StockBatch copyWith({int? quantityOnHand}) {
    return StockBatch(
      id: id,
      medicineId: medicineId,
      medicineName: medicineName,
      batchNumber: batchNumber,
      supplierName: supplierName,
      receivedOn: receivedOn,
      expiryDate: expiryDate,
      quantityReceived: quantityReceived,
      quantityOnHand: quantityOnHand ?? this.quantityOnHand,
      unitCostMinor: unitCostMinor,
      sellingPriceMinor: sellingPriceMinor,
      reorderLevel: reorderLevel,
    );
  }

  @override
  List<Object?> get props => [
        id,
        medicineId,
        medicineName,
        batchNumber,
        supplierName,
        receivedOn,
        expiryDate,
        quantityReceived,
        quantityOnHand,
        unitCostMinor,
        sellingPriceMinor,
        reorderLevel,
      ];
}

class StockAdjustmentDraft extends Equatable {
  const StockAdjustmentDraft({
    required this.batchId,
    required this.previousQuantity,
    required this.newQuantity,
    required this.reason,
    required this.note,
  });

  final String batchId;

  /// The quantity the user saw. The backend rejects the change if it moved.
  final int previousQuantity;
  final int newQuantity;
  final StockAdjustmentReason reason;
  final String note;

  @override
  List<Object?> get props => [batchId, previousQuantity, newQuantity, reason, note];
}
