import '../../../../core/result/result.dart';
import '../entities/supplier.dart';
import '../repositories/supplier_repository.dart';

class GetSuppliers {
  const GetSuppliers(this._repository);

  final SupplierRepository _repository;

  Future<Result<List<Supplier>>> call() => _repository.list();
}
