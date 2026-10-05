/// Validation messages. Kept in the domain layer so use cases and repositories
/// do not depend on presentation code.
abstract final class MedicineMessages {
  static const String nameMissing = 'Enter the medicine name.';
  static const String skuMissing = 'Enter a SKU.';
  static const String priceInvalid = 'Enter a selling price greater than zero.';
  static const String reorderInvalid = 'Reorder level must be zero or more.';
  static const String barcodeInvalid = 'Barcode can use letters, digits and dashes (4 to 32 characters).';
  static const String duplicateSku = 'Another medicine already uses this SKU.';
  static const String duplicateBarcode = 'Another medicine already uses this barcode.';
  static const String notFound = 'This medicine no longer exists.';
}
