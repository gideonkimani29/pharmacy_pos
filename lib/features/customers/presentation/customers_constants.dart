import '../../checkout/domain/entities/payment.dart';

abstract final class CustomersStrings {
  static const String title = 'Customers';
  static const String subtitle = 'Registered customers, credit limits and what they owe';
  static const String addCustomer = 'Add customer';
  static const String editCustomer = 'Edit customer';

  static const String kpiActive = 'Active customers';
  static const String kpiOwed = 'Owed to the pharmacy';
  static const String kpiOwing = 'Customers owing';
  static const String kpiOverLimit = 'Over credit limit';

  static const String searchHint = 'Search by name, phone or email';
  static const String filterAll = 'All';
  static const String filterOwing = 'Owing';
  static const String filterOverLimit = 'Over limit';
  static const String filterInactive = 'Inactive';
  static String filterLabel(String label, int count) => '$label ($count)';

  static const String colCustomer = 'Customer';
  static const String colLimit = 'Credit limit';
  static const String colBalance = 'Owes';
  static const String colAvailable = 'Available credit';
  static const String colLastPurchase = 'Last purchase';
  static const String colActive = 'Active';
  static const String colActions = 'Actions';
  static const String overLimitPill = 'Over limit';
  static const String noCredit = 'No credit';
  static const String never = 'Never';
  static const String receivePayment = 'Receive payment';
  static const String receiveShort = 'Receive';
  static const String editTooltip = 'Edit customer';
  static const String activeTooltip = 'Inactive customers cannot be picked at checkout';

  static const String emptyTitle = 'No customers yet';
  static const String emptyHint = 'Add the first customer to start selling on credit.';
  static String noMatches(String query) => 'No customers match "$query"';
  static const String noMatchesFilter = 'No customers in this view.';
  static const String loadFailed = 'Could not load customers';
  static const String retry = 'Try again';

  static const String fieldName = 'Customer name';
  static const String fieldPhone = 'Phone number';
  static const String fieldEmail = 'Email (optional)';
  static const String fieldLimit = 'Credit limit';
  static const String limitHint = 'Use 0 if this customer may not buy on credit.';
  static const String balanceNote = 'The balance changes through credit sales and payments, not here.';
  static const String save = 'Save';
  static const String saving = 'Saving...';
  static const String cancel = 'Cancel';

  static String paymentTitle(String name) => 'Payment from $name';
  static String currentBalance(String amount) => 'Currently owes $amount';
  static const String fieldAmount = 'Amount received';
  static const String fullBalance = 'Full balance';
  static const String referenceCard = 'Card approval code';
  static const String referenceMobile = 'M-Pesa transaction code';
  static const String recordPayment = 'Record payment';
  static String balanceAfter(String amount) => 'Balance after this payment: $amount';
  static const String methodCash = 'Cash';
  static const String methodCard = 'Card';
  static const String methodMobile = 'Mobile';

  static String saved(String name) => '$name saved.';
  static String activated(String name) => '$name is active again.';
  static String deactivated(String name) => '$name is inactive.';
  static String paymentReceived(String amount, String name, String balance) =>
      '$amount received from $name. Balance now $balance.';

  static String methodLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => methodCash,
        PaymentMethod.card => methodCard,
        PaymentMethod.mobile => methodMobile,
      };

  static String? referenceLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => null,
        PaymentMethod.card => referenceCard,
        PaymentMethod.mobile => referenceMobile,
      };
}

abstract final class CustomersLayout {
  static const double compactBreakpoint = 1000;
  static const double kpiWidth = 280;
  static const double formDialogWidth = 480;
  static const double paymentDialogWidth = 460;
  static const double inactiveOpacity = 0.55;
  static const double limitColumnWidth = 120;
  static const double balanceColumnWidth = 140;
  static const double availableColumnWidth = 130;
  static const double lastPurchaseColumnWidth = 130;
  static const double activeColumnWidth = 80;
  static const double actionsColumnWidth = 150;
  static const double actionsColumnCompactWidth = 110;
  static const int nameFlex = 5;
}
