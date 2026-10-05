import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../entities/purchase.dart';
import '../purchase_messages.dart';
import '../repositories/purchase_repository.dart';

/// Validates a purchase locally for fast feedback. The Go backend repeats
/// every check; this is a convenience, never the authority.
class RecordPurchase {
  const RecordPurchase(this._repository);

  final PurchaseRepository _repository;

  Future<Result<Purchase>> call(PurchaseRequest request) {
    final failure = _validate(request);
    if (failure != null) return Future.value(Err<Purchase>(failure));
    return _repository.record(request);
  }

  Failure? _validate(PurchaseRequest request) {
    final supplierId = request.supplierId;
    if (supplierId == null || supplierId.isEmpty) return const ValidationFailure(PurchaseMessages.noSupplier);
    if (request.invoiceNumber.trim().isEmpty) return const ValidationFailure(PurchaseMessages.noInvoice);
    if (request.lines.isEmpty) return const ValidationFailure(PurchaseMessages.noLines);

    final seenBatches = <String>{};
    for (final line in request.lines) {
      if (line.batchNumber.trim().isEmpty) return const ValidationFailure(PurchaseMessages.batchMissing);

      final expiry = line.expiryDate;
      if (expiry == null) return const ValidationFailure(PurchaseMessages.expiryMissing);
      if (!expiry.isAfter(request.receivedOn)) return const ValidationFailure(PurchaseMessages.expiryPast);

      if (line.quantity < 1) return const ValidationFailure(PurchaseMessages.quantityInvalid);
      if (line.unitCostMinor <= 0) return const ValidationFailure(PurchaseMessages.costInvalid);
      if (line.sellingPriceMinor <= 0) return const ValidationFailure(PurchaseMessages.priceInvalid);

      final batchKey = '${line.productId}|${line.batchNumber.trim().toUpperCase()}';
      if (!seenBatches.add(batchKey)) return const ValidationFailure(PurchaseMessages.duplicateBatch);
    }
    return null;
  }
}
