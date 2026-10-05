import '../../../../core/result/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class FindProductByBarcode {
  const FindProductByBarcode(this._repository);

  final ProductRepository _repository;

  Future<Result<Product?>> call(String barcode) => _repository.findByBarcode(barcode.trim());
}
