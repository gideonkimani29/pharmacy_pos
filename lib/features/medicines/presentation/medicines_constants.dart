import '../domain/entities/medicine.dart';

abstract final class MedicinesStrings {
  static const String title = 'Medicines';
  static const String subtitle = 'The product catalogue: prices, prescription flags and reorder levels';
  static const String addMedicine = 'Add medicine';
  static const String editMedicine = 'Edit medicine';

  static const String kpiActive = 'Active medicines';
  static const String kpiLow = 'Low stock';
  static const String kpiOut = 'Out of stock';
  static const String kpiRx = 'Prescription only';

  static const String searchHint = 'Search by name, generic name, SKU or barcode';
  static const String filterAll = 'All';
  static const String filterLow = 'Low stock';
  static const String filterOut = 'Out of stock';
  static const String filterRx = 'Rx only';
  static const String filterInactive = 'Inactive';
  static String filterLabel(String label, int count) => '$label ($count)';

  static const String colMedicine = 'Medicine';
  static const String colGeneric = 'Generic';
  static const String colPrice = 'Price';
  static const String colStock = 'Stock';
  static const String colReorder = 'Reorder at';
  static const String colActive = 'Active';
  static const String colEdit = 'Edit';
  static String detailLine(String sku, String barcode, String form) =>
      barcode.isEmpty ? '$sku  ·  $form' : '$sku  ·  $barcode  ·  $form';
  static const String stockOut = 'Out';
  static const String editTooltip = 'Edit medicine';
  static const String activeTooltip = 'Active medicines can be sold';

  static const String emptyTitle = 'No medicines yet';
  static const String emptyHint = 'Add the first medicine to build the catalogue.';
  static String noMatches(String query) => 'No medicines match "$query"';
  static const String noMatchesFilter = 'No medicines in this view.';
  static const String loadFailed = 'Could not load medicines';
  static const String retry = 'Try again';

  static const String fieldName = 'Medicine name';
  static const String fieldGeneric = 'Generic name';
  static const String fieldForm = 'Dosage form';
  static const String fieldSku = 'SKU';
  static const String fieldBarcode = 'Barcode (optional)';
  static const String fieldPrice = 'Selling price';
  static const String fieldReorder = 'Reorder level';
  static const String fieldRx = 'Prescription only (Rx)';
  static const String fieldRxHint = 'The cashier must confirm a pharmacist check at checkout.';
  static const String stockNote = 'Stock changes through purchases and stock adjustments, not here.';
  static const String save = 'Save';
  static const String saving = 'Saving...';
  static const String cancel = 'Cancel';

  static String saved(String name) => '$name saved.';
  static String activated(String name) => '$name is active again.';
  static String deactivated(String name) => '$name is inactive and will not be sold.';

  static String formLabel(DosageForm form) => switch (form) {
        DosageForm.tablet => 'Tablet',
        DosageForm.capsule => 'Capsule',
        DosageForm.syrup => 'Syrup or suspension',
        DosageForm.injection => 'Injection',
        DosageForm.cream => 'Cream or ointment',
        DosageForm.drops => 'Drops',
        DosageForm.inhaler => 'Inhaler',
        DosageForm.sachet => 'Sachet or powder',
        DosageForm.other => 'Other',
      };
}

abstract final class MedicinesLayout {
  static const double compactBreakpoint = 900;
  static const double kpiWidth = 280;
  static const double stockColumnWidth = 90;
  static const double reorderColumnWidth = 90;
  static const double activeColumnWidth = 80;
  static const double editColumnWidth = 56;
  static const double inactiveOpacity = 0.55;
  static const int defaultReorderLevel = 10;
  static const double formDialogWidth = 560;
  static const double halfFieldWidth = 270;
  static const int nameFlex = 6;
  static const int genericFlex = 3;
  static const int priceFlex = 2;
}
