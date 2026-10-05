import '../../../../core/result/result.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class GetCustomers {
  const GetCustomers(this._repository);

  final CustomerRepository _repository;

  Future<Result<List<Customer>>> call() => _repository.list();
}
