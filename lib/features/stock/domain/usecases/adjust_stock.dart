import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../entities/stock_batch.dart';
import '../repositories/stock_repository.dart';
import '../stock_messages.dart';

/// Validates a stock adjustment locally for fast feedback. The Go backend
/// repeats every check and writes the audit entry.
class AdjustStock {
  const AdjustStock(this._repository);

  final StockRepository _repository;

  Future<Result<StockBatch>> call(StockAdjustmentDraft draft) {
    final failure = _validate(draft);
    if (failure != null) return Future.value(Err<StockBatch>(failure));
    return _repository.adjust(draft);
  }

  Failure? _validate(StockAdjustmentDraft draft) {
    if (draft.newQuantity < 0) return const ValidationFailure(StockMessages.quantityInvalid);
    if (draft.newQuantity == draft.previousQuantity) return const ValidationFailure(StockMessages.noChange);

    final canIncrease = draft.reason == StockAdjustmentReason.countCorrection ||
        draft.reason == StockAdjustmentReason.other;
    if (!canIncrease && draft.newQuantity > draft.previousQuantity) {
      return const ValidationFailure(StockMessages.mustDecrease);
    }

    if (draft.reason == StockAdjustmentReason.other && draft.note.trim().isEmpty) {
      return const ValidationFailure(StockMessages.noteRequired);
    }
    return null;
  }
}
