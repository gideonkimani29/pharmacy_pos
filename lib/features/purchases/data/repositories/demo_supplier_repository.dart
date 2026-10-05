import '../../../../core/result/result.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';

class DemoSupplierRepository implements SupplierRepository {
  static const Duration _latency = Duration(milliseconds: 150);

  static const List<Supplier> suppliers = [
    Supplier(id: 's1', name: 'Eldoret Pharma Wholesalers', phone: '+254700100001'),
    Supplier(id: 's2', name: 'Highlands Medical Distributors', phone: '+254700100002'),
    Supplier(id: 's3', name: 'Rift Valley Pharma Supplies', phone: '+254700100003'),
    Supplier(id: 's4', name: 'Nairobi Generics Depot', phone: '+254700100004'),
  ];

  @override
  Future<Result<List<Supplier>>> list() async {
    await Future<void>.delayed(_latency);
    return const Ok(suppliers);
  }
}
