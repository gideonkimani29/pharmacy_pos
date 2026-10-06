import '../../../../core/result/result.dart';
import '../entities/stock_batch.dart';
import '../repositories/stock_repository.dart';

class GetStockBatches {
  const GetStockBatches(this._repository);

  final StockRepository _repository;

  Future<Result<List<StockBatch>>> call() => _repository.list();
}
