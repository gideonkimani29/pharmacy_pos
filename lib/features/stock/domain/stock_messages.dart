abstract final class StockMessages {
  static const String quantityInvalid = 'Enter the new quantity (0 or more).';
  static const String noChange = 'The new quantity is the same as the current one.';
  static const String mustDecrease = 'This reason can only reduce the quantity.';
  static const String noteRequired = 'Add a note to explain this adjustment.';
  static const String notFound = 'This batch no longer exists.';
  static const String changedElsewhere = 'This batch changed since you opened it. Reload and try again.';
}
