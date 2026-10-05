import 'package:equatable/equatable.dart';

enum DosageForm { tablet, capsule, syrup, injection, cream, drops, inhaler, sachet, other }

enum StockLevel { out, low, ok }

/// What the user edits. Stock and active state are not edited here.
class MedicineDraft extends Equatable {
  const MedicineDraft({
    required this.name,
    required this.genericName,
    required this.dosageForm,
    required this.sku,
    required this.barcode,
    required this.sellingPriceMinor,
    required this.reorderLevel,
    required this.requiresPrescription,
  });

  final String name;
  final String genericName;
  final DosageForm dosageForm;
  final String sku;

  /// Empty when the product has no barcode.
  final String barcode;
  final int sellingPriceMinor;
  final int reorderLevel;
  final bool requiresPrescription;

  @override
  List<Object?> get props => [
        name,
        genericName,
        dosageForm,
        sku,
        barcode,
        sellingPriceMinor,
        reorderLevel,
        requiresPrescription,
      ];
}

class Medicine extends Equatable {
  const Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.dosageForm,
    required this.sku,
    required this.barcode,
    required this.sellingPriceMinor,
    required this.reorderLevel,
    required this.requiresPrescription,
    required this.isActive,
    required this.stockOnHand,
  });

  final String id;
  final String name;
  final String genericName;
  final DosageForm dosageForm;
  final String sku;
  final String barcode;
  final int sellingPriceMinor;
  final int reorderLevel;
  final bool requiresPrescription;
  final bool isActive;

  /// Read-only here. Changed by purchases, sales and stock adjustments.
  final int stockOnHand;

  StockLevel get stockLevel {
    if (stockOnHand <= 0) return StockLevel.out;
    if (stockOnHand <= reorderLevel) return StockLevel.low;
    return StockLevel.ok;
  }

  Medicine copyWith({bool? isActive}) {
    return Medicine(
      id: id,
      name: name,
      genericName: genericName,
      dosageForm: dosageForm,
      sku: sku,
      barcode: barcode,
      sellingPriceMinor: sellingPriceMinor,
      reorderLevel: reorderLevel,
      requiresPrescription: requiresPrescription,
      isActive: isActive ?? this.isActive,
      stockOnHand: stockOnHand,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        genericName,
        dosageForm,
        sku,
        barcode,
        sellingPriceMinor,
        reorderLevel,
        requiresPrescription,
        isActive,
        stockOnHand,
      ];
}
