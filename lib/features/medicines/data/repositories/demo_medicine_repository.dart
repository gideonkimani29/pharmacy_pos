import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/medicine.dart';
import '../../domain/medicine_messages.dart';
import '../../domain/repositories/medicine_repository.dart';

class DemoMedicineRepository implements MedicineRepository {
  DemoMedicineRepository({List<Medicine> medicines = const []}) : _items = [...medicines];

  static const Duration _latency = Duration(milliseconds: 250);
  static const String _idPrefix = 'm';
  static const int _firstNewId = 100;

  final List<Medicine> _items;
  int _counter = _firstNewId;

  @override
  Future<Result<List<Medicine>>> list() async {
    await Future<void>.delayed(_latency);
    return Ok([..._items]);
  }

  @override
  Future<Result<Medicine>> create(MedicineDraft draft) async {
    await Future<void>.delayed(_latency);
    final clash = _clash(draft, exceptId: null);
    if (clash != null) return Err<Medicine>(clash);

    final medicine = Medicine(
      id: '$_idPrefix${_counter++}',
      name: draft.name.trim(),
      genericName: draft.genericName.trim(),
      dosageForm: draft.dosageForm,
      sku: draft.sku.trim(),
      barcode: draft.barcode.trim(),
      sellingPriceMinor: draft.sellingPriceMinor,
      reorderLevel: draft.reorderLevel,
      requiresPrescription: draft.requiresPrescription,
      isActive: true,
      stockOnHand: 0,
    );
    _items.add(medicine);
    return Ok(medicine);
  }

  @override
  Future<Result<Medicine>> update(String id, MedicineDraft draft) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((m) => m.id == id);
    if (index < 0) return const Err<Medicine>(ValidationFailure(MedicineMessages.notFound));

    final clash = _clash(draft, exceptId: id);
    if (clash != null) return Err<Medicine>(clash);

    final current = _items[index];
    final updated = Medicine(
      id: id,
      name: draft.name.trim(),
      genericName: draft.genericName.trim(),
      dosageForm: draft.dosageForm,
      sku: draft.sku.trim(),
      barcode: draft.barcode.trim(),
      sellingPriceMinor: draft.sellingPriceMinor,
      reorderLevel: draft.reorderLevel,
      requiresPrescription: draft.requiresPrescription,
      isActive: current.isActive,
      stockOnHand: current.stockOnHand,
    );
    _items[index] = updated;
    return Ok(updated);
  }

  @override
  Future<Result<Medicine>> setActive(String id, {required bool active}) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((m) => m.id == id);
    if (index < 0) return const Err<Medicine>(ValidationFailure(MedicineMessages.notFound));
    _items[index] = _items[index].copyWith(isActive: active);
    return Ok(_items[index]);
  }

  Failure? _clash(MedicineDraft draft, {required String? exceptId}) {
    final sku = draft.sku.trim().toLowerCase();
    final barcode = draft.barcode.trim().toLowerCase();
    for (final item in _items) {
      if (item.id == exceptId) continue;
      if (item.sku.toLowerCase() == sku) return const ValidationFailure(MedicineMessages.duplicateSku);
      if (barcode.isNotEmpty && item.barcode.toLowerCase() == barcode) {
        return const ValidationFailure(MedicineMessages.duplicateBarcode);
      }
    }
    return null;
  }

}
