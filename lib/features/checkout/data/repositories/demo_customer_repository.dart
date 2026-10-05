import '../../../../core/result/result.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

class DemoCustomerRepository implements CustomerRepository {
  static const Duration _latency = Duration(milliseconds: 150);

  static const List<Customer> _customers = [
    Customer(id: 'c1', name: 'Mary Chebet', phone: '+254700000001'),
    Customer(id: 'c2', name: 'Uasin Gishu Community Clinic', phone: '+254700000002'),
    Customer(id: 'c3', name: 'Kapsabet SACCO Staff Account', phone: '+254700000003'),
    Customer(id: 'c4', name: 'John Kiprono', phone: '+254700000004'),
  ];

  @override
  Future<Result<List<Customer>>> list() async {
    await Future<void>.delayed(_latency);
    return const Ok(_customers);
  }
}
