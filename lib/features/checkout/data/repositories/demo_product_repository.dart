import '../../../../core/result/result.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

class DemoProductRepository implements ProductRepository {
  DemoProductRepository({List<Product> products = const []})
      : _catalog = [...products];

  static const Duration _latency = Duration(milliseconds: 120);
  final List<Product> _catalog;

  @override
  Future<Result<List<Product>>> search(String query) async {
    await Future<void>.delayed(_latency);
    final needle = query.toLowerCase();
    if (needle.isEmpty) return Ok(_catalog);
    final matches = _catalog.where((p) {
      return p.name.toLowerCase().contains(needle) ||
          p.genericName.toLowerCase().contains(needle) ||
          p.sku.toLowerCase().contains(needle) ||
          p.barcode.contains(needle);
    }).toList();
    return Ok(matches);
  }

  @override
  Future<Result<Product?>> findByBarcode(String barcode) async {
    await Future<void>.delayed(_latency);
    for (final product in _catalog) {
      if (product.barcode == barcode) return Ok(product);
    }
    return const Ok(null);
  }
}
