import '../../../../core/result/result.dart';
import '../entities/customer_account.dart';
import '../repositories/customer_account_repository.dart';

class GetCustomerAccounts {
  const GetCustomerAccounts(this._repository);

  final CustomerAccountRepository _repository;

  Future<Result<List<CustomerAccount>>> call() => _repository.list();
}
