import '../../../../core/result/result.dart';
import '../entities/customer_account.dart';

abstract interface class CustomerAccountRepository {
  Future<Result<List<CustomerAccount>>> list();
  Future<Result<CustomerAccount>> create(CustomerDraft draft);
  Future<Result<CustomerAccount>> update(String id, CustomerDraft draft);
  Future<Result<CustomerAccount>> setActive(String id, {required bool active});

  /// Reduces the customer's balance and records the receipt, atomically.
  Future<Result<CustomerAccount>> receivePayment(AccountPaymentDraft draft);
}
