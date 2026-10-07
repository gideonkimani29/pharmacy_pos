abstract final class SettingsMessages {
  static const String nameMissing = 'Enter the pharmacy name.';
  static const String phoneInvalid = 'Enter a phone number with 9 to 15 digits (a leading + is fine).';
  static const String emailInvalid = 'Enter a valid email address.';
  static const String pinInvalid = 'A KRA PIN looks like A123456789B (a letter, 9 digits, a letter).';
  static const String taxInvalid = 'Enter a tax rate between 0 and 100.';
  static const String discountInvalid = 'Enter a whole number between 0 and 100.';
  static const String copiesInvalid = 'Receipt copies must be between 1 and 5.';
  static const String footerTooLong = 'The receipt footer can be up to 160 characters.';

  static const String userNameMissing = 'Enter the user\'s full name.';
  static const String userEmailMissing = 'Enter the email address the user will sign in with.';
  static const String duplicateEmail = 'Another user already uses this email.';
  static const String lastAdmin = 'There must always be at least one active admin.';
  static const String userNotFound = 'This user no longer exists.';
}
