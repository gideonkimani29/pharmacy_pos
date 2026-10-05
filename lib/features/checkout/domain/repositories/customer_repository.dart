import '../../../../core/result/result.dart';
import '../entities/customer.dart';

abstract interface class CustomerRepository {
  Future<Result<List<Customer>>> list();
}
