import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../entities/medicine.dart';
import '../medicine_messages.dart';
import '../repositories/medicine_repository.dart';

/// Creates a medicine, or updates one when [id] is given. Validates locally
/// for fast feedback; the Go backend repeats every check and also enforces
/// SKU and barcode uniqueness.
class SaveMedicine {
  const SaveMedicine(this._repository);

  static final RegExp _barcodePattern = RegExp(r'^[A-Za-z0-9\-]{4,32}$');

  final MedicineRepository _repository;

  Future<Result<Medicine>> call(MedicineDraft draft, {String? id}) {
    final failure = _validate(draft);
    if (failure != null) return Future.value(Err<Medicine>(failure));
    return id == null ? _repository.create(draft) : _repository.update(id, draft);
  }

  Failure? _validate(MedicineDraft draft) {
    if (draft.name.trim().isEmpty) return const ValidationFailure(MedicineMessages.nameMissing);
    if (draft.sku.trim().isEmpty) return const ValidationFailure(MedicineMessages.skuMissing);
    if (draft.sellingPriceMinor <= 0) return const ValidationFailure(MedicineMessages.priceInvalid);
    if (draft.reorderLevel < 0) return const ValidationFailure(MedicineMessages.reorderInvalid);

    final barcode = draft.barcode.trim();
    if (barcode.isNotEmpty && !_barcodePattern.hasMatch(barcode)) {
      return const ValidationFailure(MedicineMessages.barcodeInvalid);
    }
    return null;
  }
}
