import '../../../../core/result/result.dart';
import '../entities/customer_account.dart';
import '../repositories/customer_account_repository.dart';

class SetCustomerActive {
  const SetCustomerActive(this._repository);

  final CustomerAccountRepository _repository;

  Future<Result<CustomerAccount>> call(String id, {required bool active}) =>
      _repository.setActive(id, active: active);
}
