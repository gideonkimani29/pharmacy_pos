import '../../../../core/result/result.dart';
import '../entities/supplier.dart';

abstract interface class SupplierRepository {
  Future<Result<List<Supplier>>> list();
}
