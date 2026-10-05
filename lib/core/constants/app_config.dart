/// Behavioural constants. Anything tunable lives here, never inline.
abstract final class AppConfig {
  static const String currencyCode = 'KES';
  static const int minorUnitsPerMajor = 100;

  /// Tax rate in basis points (1600 = 16%). Most medicines are VAT-exempt in
  /// Kenya, so the default is 0; the backend remains the source of truth.
  static const int taxRateBasisPoints = 0;
  static const int basisPointsDenominator = 10000;

  static const int maxLineQuantity = 999;
  static const int minPaymentReferenceLength = 6;

  static const Duration searchDebounce = Duration(milliseconds: 250);

  /// HID scanners "type" far faster than humans. Keys arriving further apart
  /// than this gap start a new buffer.
  static const Duration scannerMaxKeyGap = Duration(milliseconds: 60);
  static const int scannerMinLength = 6;

  static const int expiryCriticalDays = 30;
  static const int expiryWarningDays = 60;
  static const int expiryNoticeDays = 90;

  /// Quick-cash buttons in the payment dialog, in minor units (KES 100, 200, 500, 1,000).
  static const List<int> quickCashMinor = [10000, 20000, 50000, 100000];
  static const double emptyCartHeight = 180;
}
