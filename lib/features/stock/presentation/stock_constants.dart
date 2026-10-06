import '../domain/entities/stock_batch.dart';

abstract final class StockStrings {
  static const String title = 'Stock & Batches';
  static const String subtitle = 'Every batch on the shelf: expiry, quantity and cost';

  static const String kpiSellable = 'Sellable units';
  static const String kpiValue = 'Stock value (at cost)';
  static const String kpiExpiring = 'Batches expiring in 90 days';
  static const String kpiExpired = 'Expired units to write off';

  static const String viewBatches = 'Batches';
  static const String viewMedicines = 'By medicine';
  static const String searchHint = 'Search by medicine, batch number or supplier';

  static const String filterAll = 'All';
  static const String filterExpired = 'Expired';
  static const String filter30 = '0-30 days';
  static const String filter60 = '31-60 days';
  static const String filter90 = '61-90 days';
  static const String filterEmpty = 'Empty';
  static String filterLabel(String label, int count) => '$label ($count)';

  static const String colMedicine = 'Medicine';
  static const String colBatch = 'Batch';
  static const String colExpiry = 'Expiry';
  static const String colOnHand = 'On hand';
  static const String colCost = 'Unit cost';
  static const String colPrice = 'Price';
  static const String colReceived = 'Received';
  static const String colAction = 'Action';
  static const String colSellable = 'Sellable';
  static const String colTotal = 'Total on hand';
  static const String colBatches = 'Batches';
  static const String colNextExpiry = 'Sells first expires';
  static const String colReorder = 'Reorder at';
  static String onHandOf(int onHand, int received) => '$onHand of $received';
  static String batchCount(int count) => count == 1 ? '1 batch' : '$count batches';
  static const String fefoNext = 'Sells first';
  static const String expiredPill = 'Expired';
  static const String emptyPill = 'Empty';
  static const String stockOutPill = 'Out';
  static const String adjust = 'Adjust';
  static const String adjustTooltip = 'Adjust or write off this batch';
  static const String noNextExpiry = 'None';

  static const String emptyTitle = 'No stock recorded yet';
  static const String emptyHint = 'Record a purchase to add the first batch.';
  static const String noMatches = 'Nothing matches this search or filter.';
  static const String loadFailed = 'Could not load stock';
  static const String retry = 'Try again';

  static const String adjustTitle = 'Adjust stock';
  static String batchHeading(String medicine, String batch) => '$medicine  ·  batch $batch';
  static String currentQuantity(int quantity) => 'Currently on hand: $quantity';
  static const String fieldReason = 'Reason';
  static const String fieldNewQuantity = 'New quantity';
  static const String fieldNote = 'Note (required for "Other")';
  static const String writeOffHint = 'This batch has expired. Write it off so it cannot be sold.';
  static const String save = 'Save adjustment';
  static const String saving = 'Saving...';
  static const String cancel = 'Cancel';
  static String adjusted(String medicine, String batch) => 'Stock for $medicine (batch $batch) updated.';

  static String reasonLabel(StockAdjustmentReason reason) => switch (reason) {
        StockAdjustmentReason.expired => 'Expired write-off',
        StockAdjustmentReason.damaged => 'Damaged or lost',
        StockAdjustmentReason.returnedToSupplier => 'Returned to supplier',
        StockAdjustmentReason.countCorrection => 'Stock count correction',
        StockAdjustmentReason.other => 'Other',
      };
}

abstract final class StockLayout {
  static const double compactBreakpoint = 1000;
  static const double kpiWidth = 280;
  static const double dialogWidth = 460;
  static const double inactiveOpacity = 0.6;
  static const double batchColumnWidth = 100;
  static const double expiryColumnWidth = 150;
  static const double onHandColumnWidth = 110;
  static const double moneyColumnWidth = 110;
  static const double receivedColumnWidth = 150;
  static const double actionColumnWidth = 90;
  static const double sellableColumnWidth = 100;
  static const double totalColumnWidth = 110;
  static const double batchesColumnWidth = 100;
  static const double nextExpiryColumnWidth = 150;
  static const double reorderColumnWidth = 100;
  static const int nameFlex = 5;
}
