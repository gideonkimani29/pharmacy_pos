abstract final class CustomerMessages {
  static const String nameMissing = 'Enter the customer name.';
  static const String phoneInvalid = 'Enter a phone number with 9 to 15 digits (a leading + is fine).';
  static const String emailInvalid = 'Enter a valid email address, or leave it empty.';
  static const String limitInvalid = 'Credit limit must be zero or more.';
  static const String duplicatePhone = 'Another customer already uses this phone number.';
  static const String notFound = 'This customer no longer exists.';
  static const String paymentAmountInvalid = 'Enter a payment amount greater than zero.';
  static const String paymentExceedsBalance = 'The payment is more than the customer owes.';
  static const String noBalance = 'This customer has nothing outstanding.';
  static String referenceShort(int min) => 'Enter the reference code ($min characters or more).';
}
