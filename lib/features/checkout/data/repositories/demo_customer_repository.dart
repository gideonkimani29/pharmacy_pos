import '../../../../core/result/result.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class DemoCustomerRepository implements CustomerRepository {
  DemoCustomerRepository({List<Customer> customers = const []})
      : _customers = [...customers];

  static const Duration _latency = Duration(milliseconds: 150);
  final List<Customer> _customers;

  @override
  Future<Result<List<Customer>>> list() async {
    await Future<void>.delayed(_latency);
    return Ok([..._customers]);
  }
}
