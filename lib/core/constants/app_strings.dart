/// All user-facing copy. Swap for gen-l10n later without touching widgets.
abstract final class AppStrings {
  static const String appTitle = 'Pharmacy POS';

  // Shortcut legend
  static const String shortcutSearchKey = 'F1';
  static const String shortcutSearchLabel = 'Search';
  static const String shortcutPayKey = 'F2';
  static const String shortcutPayLabel = 'Pay';
  static const String shortcutClearKey = 'Esc';
  static const String shortcutClearLabel = 'Clear sale';

  // Catalog
  static const String searchHint = 'Search by name, generic name, SKU, or scan a barcode';
  static const String productsLoadFailed = 'Could not load products';
  static const String retry = 'Try again';
  static const String rxBadge = 'Rx';
  static const String stockOut = 'Out of stock';
  static const String expired = 'Expired';
  static const String expiryPrefix = 'Exp';
  static String stockIn(int qty) => '$qty in stock';
  static String stockLow(int qty) => 'Only $qty left';
  static String noResults(String query) => 'No products match "$query"';
  static const String noProducts = 'No products available';

  // Cart
  static const String currentSale = 'Current sale';
  static const String clearSale = 'Clear';
  static const String cartEmptyTitle = 'Cart is empty';
  static const String cartEmptyHint = 'Search or scan a barcode to add the first item.';
  static const String rxBannerTitle = 'Prescription-only items in this sale';
  static const String rxVerifiedLabel = 'Prescription checked by pharmacist';
  static const String subtotal = 'Subtotal';
  static const String tax = 'Tax';
  static const String total = 'Total';
  static const String processing = 'Processing sale...';
  static String itemsCount(int units) => units == 1 ? '1 item' : '$units items';
  static String chargeButton(String amount) => 'Charge $amount';
  static String lineUnitPrice(String price) => '$price each';
  static const String removeItem = 'Remove item';
  static const String decreaseQuantity = 'Decrease quantity';
  static const String increaseQuantity = 'Increase quantity';

  // Clear confirmation
  static const String clearConfirmTitle = 'Clear this sale?';
  static const String clearConfirmBody = 'All items will be removed from the cart.';
  static const String keepSale = 'Keep sale';
  static const String clearConfirmAction = 'Clear sale';

  // Payment
  static const String paymentTitle = 'Take payment';
  static const String amountDue = 'Amount due';
  static const String methodCash = 'Cash';
  static const String methodCard = 'Card';
  static const String methodMobile = 'Mobile';
  static const String amountLabel = 'Amount';
  static const String referenceCard = 'Card approval code';
  static const String referenceMobile = 'M-Pesa transaction code';
  static const String addPayment = 'Add payment';
  static const String paymentsAdded = 'Payments added';
  static const String paid = 'Paid';
  static const String remaining = 'Remaining';
  static const String changeDue = 'Change due';
  static const String exactAmount = 'Exact';
  static const String completeSale = 'Complete sale';
  static const String cancel = 'Cancel';
  static const String removePayment = 'Remove payment';

  // Sale complete
  static const String saleComplete = 'Sale complete';
  static const String receiptNumber = 'Receipt number';
  static const String newSale = 'Start new sale';

  // Notices (snackbars)
  static const String noticeOutOfStock = 'This product has no sellable stock.';
  static const String noticeCartEmpty = 'Add at least one item before taking payment.';
  static const String noticeRxNotVerified = 'Confirm the prescription check before taking payment.';
  static String noticeMaxQuantity(int max) => 'Only $max available for this product.';
  static String noticeBarcodeNotFound(String code) => 'No product found for barcode $code.';

  // Failures
  static const String errorNetwork = 'Cannot reach the server. Check the connection and try again.';
  static const String errorUnauthorized = 'Your session has expired. Sign in again.';
  static const String errorUnexpected = 'Something went wrong. Try again.';
  static const String errorCartEmpty = 'The cart is empty.';
  static const String errorRxNotVerified = 'Prescription-only items need a pharmacist check.';
  static const String errorNoPayment = 'Add at least one payment.';
  static const String errorInvalidAmount = 'Enter an amount greater than zero.';
  static const String errorPaymentShort = 'Payments do not cover the total.';
  static const String errorNonCashOverpay = 'Card and mobile payments cannot exceed the amount due.';
  static const String errorAmountExceedsRemaining = 'Card and mobile payments cannot exceed the remaining balance.';
  static const String errorNothingRemaining = 'The total is already covered.';
  static String errorReferenceShort(int min) => 'Enter the reference code ($min characters or more).';

  // Shell and navigation
  static const String navDashboard = 'Dashboard';
  static const String navSales = 'Sales (POS)';
  static const String navPurchases = 'Purchases';
  static const String navMedicines = 'Medicines';
  static const String navStock = 'Stock & Batches';
  static const String navCustomers = 'Customers';
  static const String navReports = 'Reports';
  static const String navSettings = 'Settings';
  static const String moduleNotBuilt = 'This module is not built yet.';
  static const String tabNewSale = 'New sale';
  static const String tabSalesReturn = 'Sales return';
  static const String salesReturnTitle = 'Sales returns';
  static const String salesReturnHint =
      'Returns need a receipt lookup and a stock-reversal endpoint on the Go API. This tab will use them.';

  // Customer and sale type
  static const String selectCustomer = 'Select customer';
  static const String noCustomer = 'No customer (walk-in)';
  static const String customersLoadFailed = 'Could not load customers';
  static const String saleType = 'Sale type';
  static const String saleTypeCash = 'Cash sale';
  static const String saleTypeCredit = 'Credit sale';
  static const String creditConfirmTitle = 'Charge to account?';
  static String creditConfirmBody(String amount, String customer) => 'Add $amount to $customer\'s account.';
  static const String chargeToAccount = 'Charge to account';
  static const String onAccount = 'Charged to account';

  // Discount
  static const String discount = 'Discount';
  static const String editDiscount = 'Edit discount';
  static const String discountTitle = 'Apply discount';
  static const String discountHint = 'Leave empty to remove the discount.';
  static const String apply = 'Apply';

  // Tables
  static String cartItemsTitle(int units) => 'Cart items ($units)';
  static const String columnItem = 'Item';
  static const String columnQty = 'Qty';
  static const String columnTotal = 'Total';
  static const String columnMedicine = 'Medicine';
  static const String columnGeneric = 'Generic';
  static const String columnStock = 'Stock';
  static const String columnAction = 'Action';
  static const String addToCart = 'Add to cart';
  static String batchLabel(String batch) => 'BN: $batch';
  static const String proceedToCheckout = 'Proceed to checkout';

  // Notices and failures
  static const String noticeCreditNeedsCustomer = 'Select a customer before making a credit sale.';
  static const String errorCreditNeedsCustomer = 'A credit sale needs a customer.';
  static const String errorCreditOverpay = 'A deposit cannot exceed the total on a credit sale.';
  static const String errorInvalidDiscount = 'Discount cannot be negative or more than the subtotal.';

  // Dashboard
  static const String dashboardSubtitle = 'How the pharmacy is doing today';
  static const String refresh = 'Refresh';
  static const String dashboardLoadFailed = 'Could not load the dashboard';
  static const String dashboardStale = 'Showing earlier numbers. The refresh failed.';
  static const String kpiTodaySales = 'Sales today';
  static const String kpiTransactions = 'Transactions';
  static const String kpiItemsSold = 'Items sold';
  static const String kpiOnCredit = 'Owed on credit';
  static String kpiAverageSale(String amount) => 'Average $amount per sale';
  static const String salesLast7Days = 'Sales, last 7 days';
  static const String expiryWatch = 'Expiry watch';
  static const String bandExpired = 'Expired';
  static const String band30 = '0-30 days';
  static const String band60 = '31-60 days';
  static const String band90 = '61-90 days';
  static const String noExpiring = 'Nothing expired or expiring in the next 90 days.';
  static String batchQuantity(String batch, int quantity) => 'Batch $batch  ·  $quantity units';
  static const String lowStockTitle = 'Low stock';
  static const String noLowStock = 'Every product is above its reorder level.';
  static String stockOfThreshold(int stock, int threshold) => '$stock / $threshold';
  static const String topSellers = 'Top sellers, last 7 days';
  static String unitsSold(int units) => '$units sold';
}
