import '../../../../core/result/result.dart';
import '../entities/product.dart';

abstract interface class ProductRepository {
  /// Matches name, generic name, SKU or barcode. An empty query lists products.
  Future<Result<List<Product>>> search(String query);

  /// Exact barcode lookup. `Ok(null)` means the barcode is unknown.
  Future<Result<Product?>> findByBarcode(String barcode);
}
