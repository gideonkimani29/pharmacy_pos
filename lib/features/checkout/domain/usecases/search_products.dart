import '../../../../core/result/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class SearchProducts {
  const SearchProducts(this._repository);

  final ProductRepository _repository;

  Future<Result<List<Product>>> call(String query) => _repository.search(query.trim());
}
