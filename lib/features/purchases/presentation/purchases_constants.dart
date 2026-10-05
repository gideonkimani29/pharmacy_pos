/// All copy for the Purchases module.
abstract final class PurchasesStrings {
  static const String title = 'Purchases';
  static const String subtitle = 'Stock received from suppliers';
  static const String newPurchase = 'New purchase';
  static const String kpiPurchases = 'Purchases recorded';
  static const String kpiOwed = 'Owed to suppliers';

  static const String colDate = 'Date';
  static const String colReference = 'Reference';
  static const String colSupplier = 'Supplier';
  static const String colItems = 'Items';
  static const String colTotal = 'Total cost';
  static const String colStatus = 'Payment';
  static String invoiceLabel(String invoice) => 'Invoice $invoice';
  static String itemsSummary(int lines, int units) =>
      '${lines == 1 ? '1 line' : '$lines lines'}  ·  $units units';
  static const String statusPaid = 'Paid';
  static const String statusOnCredit = 'On credit';

  static const String emptyTitle = 'No purchases yet';
  static const String emptyHint = 'Record the first delivery from a supplier to add stock.';
  static const String loadFailed = 'Could not load purchases';
  static const String retry = 'Try again';

  static const String formTitle = 'Record a purchase';
  static const String back = 'Back to purchases';
  static const String supplier = 'Supplier';
  static const String invoiceNumber = 'Supplier invoice number';
  static const String receivedOn = 'Date received';
  static const String payment = 'Payment';
  static const String itemsReceived = 'Items received';
  static const String searchProducts = 'Search a product to add (name, generic, SKU or barcode)';
  static String noMatches(String query) => 'No products match "$query"';
  static const String noLines = 'No items yet. Search for a product above to add the first one.';
  static const String batchNumber = 'Batch number';
  static const String expiryDate = 'Expiry date';
  static const String selectDate = 'Select date';
  static const String quantity = 'Quantity';
  static const String unitCost = 'Unit cost';
  static const String sellingPrice = 'Selling price';
  static const String sellingBelowCost = 'Selling price is below cost.';
  static const String removeLine = 'Remove line';
  static const String summaryLines = 'Lines';
  static const String summaryUnits = 'Units';
  static const String summaryTotal = 'Total cost';
  static const String save = 'Save purchase';
  static const String saving = 'Saving...';
  static const String cancel = 'Cancel';
  static String savedMessage(String reference) => 'Purchase $reference recorded.';
  static const String suppliersLoadFailed = 'Could not load suppliers.';
}

abstract final class PurchasesLayout {
  static const double wideBreakpoint = 1000;
  static const double detailsPaneWidth = 380;
  static const double batchFieldWidth = 150;
  static const double expiryFieldWidth = 170;
  static const double quantityFieldWidth = 100;
  static const double moneyFieldWidth = 140;
  static const double statusColumnWidth = 110;
  static const int maxSearchResults = 6;
  static const int defaultShelfLifeDays = 365;
  static const int maxShelfLifeDays = 3650;
  static const int receivedLookbackDays = 365;
  static const int dateFlex = 2;
  static const int referenceFlex = 3;
  static const int supplierFlex = 4;
  static const int itemsFlex = 3;
  static const int totalFlex = 3;
}
