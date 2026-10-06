import '../../../../core/result/result.dart';
import '../entities/stock_batch.dart';

abstract interface class StockRepository {
  Future<Result<List<StockBatch>>> list();

  /// Sets the batch quantity and records an audit entry (who, why, before, after).
  Future<Result<StockBatch>> adjust(StockAdjustmentDraft draft);
}
