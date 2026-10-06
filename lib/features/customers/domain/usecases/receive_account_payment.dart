import '../../../../core/constants/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../../checkout/domain/entities/payment.dart';
import '../customer_messages.dart';
import '../entities/customer_account.dart';
import '../repositories/customer_account_repository.dart';

/// Records a payment against a customer's balance. The repository checks the
/// amount against the balance the server holds, which is the only trusted figure.
class ReceiveAccountPayment {
  const ReceiveAccountPayment(this._repository);

  final CustomerAccountRepository _repository;

  Future<Result<CustomerAccount>> call(AccountPaymentDraft draft) {
    final failure = _validate(draft);
    if (failure != null) return Future.value(Err<CustomerAccount>(failure));
    return _repository.receivePayment(draft);
  }

  Failure? _validate(AccountPaymentDraft draft) {
    if (draft.amountMinor <= 0) return const ValidationFailure(CustomerMessages.paymentAmountInvalid);
    if (draft.method.needsReference) {
      final reference = draft.reference?.trim() ?? '';
      if (reference.length < AppConfig.minPaymentReferenceLength) {
        return ValidationFailure(CustomerMessages.referenceShort(AppConfig.minPaymentReferenceLength));
      }
    }
    return null;
  }
}
