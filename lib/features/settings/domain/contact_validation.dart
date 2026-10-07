/// Shared by the settings and user use cases.
abstract final class ContactValidation {
  static final RegExp _phone = RegExp(r'^\+?[0-9]{9,15}$');
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// "+254 700-000 001" becomes "+254700000001".
  static String normalizePhone(String phone) => phone.replaceAll(RegExp(r'[\s\-()]'), '');

  static bool isValidPhone(String phone) => _phone.hasMatch(normalizePhone(phone));
  static bool isValidEmail(String email) => _email.hasMatch(email.trim());
}
