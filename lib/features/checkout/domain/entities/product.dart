import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_config.dart';

enum ExpiryStatus { none, ok, within90, within60, within30, expired }

class Product extends Equatable {
  const Product({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.genericName,
    required this.unitPriceMinor,
    required this.sellableStock,
    required this.lowStockThreshold,
    required this.requiresPrescription,
    this.nearestExpiry,
    this.nextBatchNumber,
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String genericName;
  final int unitPriceMinor;

  /// Units available from non-expired batches.
  final int sellableStock;
  final int lowStockThreshold;
  final bool requiresPrescription;

  /// Earliest expiry among batches that still have stock.
  final DateTime? nearestExpiry;

  /// The batch FEFO will draw from first. Display only: the backend allocates.
  final String? nextBatchNumber;

  bool get isOutOfStock => sellableStock <= 0;
  bool get isLowStock => !isOutOfStock && sellableStock <= lowStockThreshold;

  ExpiryStatus expiryStatus(DateTime now) {
    final expiry = nearestExpiry;
    if (expiry == null) return ExpiryStatus.none;
    if (expiry.isBefore(now)) return ExpiryStatus.expired;
    final days = expiry.difference(now).inDays;
    if (days <= AppConfig.expiryCriticalDays) return ExpiryStatus.within30;
    if (days <= AppConfig.expiryWarningDays) return ExpiryStatus.within60;
    if (days <= AppConfig.expiryNoticeDays) return ExpiryStatus.within90;
    return ExpiryStatus.ok;
  }

  bool isSellable(DateTime now) => !isOutOfStock && expiryStatus(now) != ExpiryStatus.expired;

  Product copyWith({String? nextBatchNumber}) {
    return Product(
      id: id,
      sku: sku,
      barcode: barcode,
      name: name,
      genericName: genericName,
      unitPriceMinor: unitPriceMinor,
      sellableStock: sellableStock,
      lowStockThreshold: lowStockThreshold,
      requiresPrescription: requiresPrescription,
      nearestExpiry: nearestExpiry,
      nextBatchNumber: nextBatchNumber ?? this.nextBatchNumber,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sku,
        barcode,
        name,
        genericName,
        unitPriceMinor,
        sellableStock,
        lowStockThreshold,
        requiresPrescription,
        nearestExpiry,
        nextBatchNumber,
      ];
}
