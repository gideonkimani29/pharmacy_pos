import '../../../../core/result/result.dart';
import '../entities/purchase.dart';
import '../repositories/purchase_repository.dart';

class GetPurchases {
  const GetPurchases(this._repository);

  final PurchaseRepository _repository;

  Future<Result<List<Purchase>>> call() => _repository.list();
}
