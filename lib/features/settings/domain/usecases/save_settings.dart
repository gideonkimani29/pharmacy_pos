import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../contact_validation.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';
import '../settings_messages.dart';

/// Validates settings locally for fast feedback and tidies the text before it
/// is saved. The Go backend repeats every check.
class SaveSettings {
  const SaveSettings(this._repository);

  static final RegExp _kraPin = RegExp(r'^[A-Za-z][0-9]{9}[A-Za-z]$');
  static const int maxTaxBasisPoints = 10000;
  static const int maxDiscountPercent = 100;
  static const int minCopies = 1;
  static const int maxCopies = 5;
  static const int maxFooterLength = 160;

  final SettingsRepository _repository;

  Future<Result<AppSettings>> call(AppSettings settings) {
    final failure = _validate(settings);
    if (failure != null) return Future.value(Err<AppSettings>(failure));

    final clean = settings.copyWith(
      pharmacyName: settings.pharmacyName.trim(),
      branchName: settings.branchName.trim(),
      address: settings.address.trim(),
      phone: ContactValidation.normalizePhone(settings.phone),
      email: settings.email.trim(),
      taxPin: settings.taxPin.trim().toUpperCase(),
      licenceNumber: settings.licenceNumber.trim(),
      receiptFooter: settings.receiptFooter.trim(),
    );
    return _repository.save(clean);
  }

  Failure? _validate(AppSettings s) {
    if (s.pharmacyName.trim().isEmpty) return const ValidationFailure(SettingsMessages.nameMissing);

    final phone = s.phone.trim();
    if (phone.isNotEmpty && !ContactValidation.isValidPhone(phone)) {
      return const ValidationFailure(SettingsMessages.phoneInvalid);
    }
    final email = s.email.trim();
    if (email.isNotEmpty && !ContactValidation.isValidEmail(email)) {
      return const ValidationFailure(SettingsMessages.emailInvalid);
    }
    final pin = s.taxPin.trim();
    if (pin.isNotEmpty && !_kraPin.hasMatch(pin)) return const ValidationFailure(SettingsMessages.pinInvalid);

    if (s.taxRateBasisPoints < 0 || s.taxRateBasisPoints > maxTaxBasisPoints) {
      return const ValidationFailure(SettingsMessages.taxInvalid);
    }
    if (s.maxCashierDiscountPercent < 0 || s.maxCashierDiscountPercent > maxDiscountPercent) {
      return const ValidationFailure(SettingsMessages.discountInvalid);
    }
    if (s.receiptCopies < minCopies || s.receiptCopies > maxCopies) {
      return const ValidationFailure(SettingsMessages.copiesInvalid);
    }
    if (s.receiptFooter.trim().length > maxFooterLength) {
      return const ValidationFailure(SettingsMessages.footerTooLong);
    }
    return null;
  }
}
