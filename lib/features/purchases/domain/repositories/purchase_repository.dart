import '../../../../core/result/result.dart';
import '../entities/purchase.dart';

abstract interface class PurchaseRepository {
  /// Newest first.
  Future<Result<List<Purchase>>> list();

  /// Creates the purchase and one stock batch per line, atomically.
  Future<Result<Purchase>> record(PurchaseRequest request);
}
