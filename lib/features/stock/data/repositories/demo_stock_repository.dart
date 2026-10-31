import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/stock_batch.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/stock_messages.dart';

class DemoStockRepository implements StockRepository {
  DemoStockRepository({List<StockBatch> batches = const []}) : _batches = [...batches];

  static const Duration _latency = Duration(milliseconds: 250);

  final List<StockBatch> _batches;

  @override
  Future<Result<List<StockBatch>>> list() async {
    await Future<void>.delayed(_latency);
    return Ok([..._batches]);
  }

  @override
  Future<Result<StockBatch>> adjust(StockAdjustmentDraft draft) async {
    await Future<void>.delayed(_latency);
    final index = _batches.indexWhere((b) => b.id == draft.batchId);
    if (index < 0) return const Err<StockBatch>(ValidationFailure(StockMessages.notFound));
    if (_batches[index].quantityOnHand != draft.previousQuantity) {
      return const Err<StockBatch>(ValidationFailure(StockMessages.changedElsewhere));
    }
    _batches[index] = _batches[index].copyWith(quantityOnHand: draft.newQuantity);
    return Ok(_batches[index]);
  }
}
