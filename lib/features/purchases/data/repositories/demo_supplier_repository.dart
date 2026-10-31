import '../../../../core/result/result.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';

class DemoSupplierRepository implements SupplierRepository {
  DemoSupplierRepository({List<Supplier> suppliers = const []})
      : _suppliers = [...suppliers];

  static const Duration _latency = Duration(milliseconds: 150);
  final List<Supplier> _suppliers;

  @override
  Future<Result<List<Supplier>>> list() async {
    await Future<void>.delayed(_latency);
    return Ok([..._suppliers]);
  }
}
