/// Validation messages for purchases. Kept in the domain layer so the use case
/// does not depend on presentation code.
abstract final class PurchaseMessages {
  static const String noSupplier = 'Choose a supplier.';
  static const String noInvoice = 'Enter the supplier invoice number.';
  static const String noLines = 'Add at least one item.';
  static const String batchMissing = 'Every line needs a batch number.';
  static const String expiryMissing = 'Every line needs an expiry date.';
  static const String expiryPast = 'Expiry date must be after the date received.';
  static const String quantityInvalid = 'Quantity must be at least 1 on every line.';
  static const String costInvalid = 'Enter a unit cost on every line.';
  static const String priceInvalid = 'Enter a selling price on every line.';
  static const String duplicateBatch = 'The same batch number appears twice for one product.';
}
