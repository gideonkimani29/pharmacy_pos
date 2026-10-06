import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../customer_messages.dart';
import '../entities/customer_account.dart';
import '../repositories/customer_account_repository.dart';

/// Creates a customer, or updates one when [id] is given. Validates locally for
/// fast feedback; the Go backend repeats every check and enforces unique phones.
class SaveCustomerAccount {
  const SaveCustomerAccount(this._repository);

  static final RegExp _phonePattern = RegExp(r'^\+?[0-9]{9,15}$');
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final CustomerAccountRepository _repository;

  /// "+254 700-000 001" becomes "+254700000001".
  static String normalizePhone(String phone) => phone.replaceAll(RegExp(r'[\s\-()]'), '');

  Future<Result<CustomerAccount>> call(CustomerDraft draft, {String? id}) {
    final failure = _validate(draft);
    if (failure != null) return Future.value(Err<CustomerAccount>(failure));

    final clean = CustomerDraft(
      name: draft.name.trim(),
      phone: normalizePhone(draft.phone),
      email: draft.email.trim(),
      creditLimitMinor: draft.creditLimitMinor,
    );
    return id == null ? _repository.create(clean) : _repository.update(id, clean);
  }

  Failure? _validate(CustomerDraft draft) {
    if (draft.name.trim().isEmpty) return const ValidationFailure(CustomerMessages.nameMissing);
    if (!_phonePattern.hasMatch(normalizePhone(draft.phone))) {
      return const ValidationFailure(CustomerMessages.phoneInvalid);
    }
    final email = draft.email.trim();
    if (email.isNotEmpty && !_emailPattern.hasMatch(email)) {
      return const ValidationFailure(CustomerMessages.emailInvalid);
    }
    if (draft.creditLimitMinor < 0) return const ValidationFailure(CustomerMessages.limitInvalid);
    return null;
  }
}
