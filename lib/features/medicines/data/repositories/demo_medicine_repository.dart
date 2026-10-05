import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/medicine.dart';
import '../../domain/medicine_messages.dart';
import '../../domain/repositories/medicine_repository.dart';

/// In-memory catalogue so the module can be built before the Go API exists.
/// Replace with a REST-backed repository.
class DemoMedicineRepository implements MedicineRepository {
  DemoMedicineRepository() {
    _items.addAll(_seed);
  }

  static const Duration _latency = Duration(milliseconds: 250);
  static const String _idPrefix = 'm';
  static const int _firstNewId = 100;

  final List<Medicine> _items = [];
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

  static const List<Medicine> _seed = [
    Medicine(id: 'm1', name: 'Panadol 500mg x24', genericName: 'Paracetamol', dosageForm: DosageForm.tablet, sku: 'PAR-500', barcode: '6161100010011', sellingPriceMinor: 18000, reorderLevel: 20, requiresPrescription: false, isActive: true, stockOnHand: 140),
    Medicine(id: 'm2', name: 'Amoxil 500mg capsules x21', genericName: 'Amoxicillin', dosageForm: DosageForm.capsule, sku: 'AMX-500', barcode: '6161100010028', sellingPriceMinor: 45000, reorderLevel: 15, requiresPrescription: true, isActive: true, stockOnHand: 62),
    Medicine(id: 'm3', name: 'ORS sachet', genericName: 'Oral rehydration salts', dosageForm: DosageForm.sachet, sku: 'ORS-SAC', barcode: '6161100010035', sellingPriceMinor: 3500, reorderLevel: 25, requiresPrescription: false, isActive: true, stockOnHand: 8),
    Medicine(id: 'm4', name: 'Brufen 400mg x30', genericName: 'Ibuprofen', dosageForm: DosageForm.tablet, sku: 'IBU-400', barcode: '6161100010042', sellingPriceMinor: 32000, reorderLevel: 15, requiresPrescription: false, isActive: true, stockOnHand: 55),
    Medicine(id: 'm5', name: 'Glucophage 500mg x60', genericName: 'Metformin', dosageForm: DosageForm.tablet, sku: 'MET-500', barcode: '6161100010059', sellingPriceMinor: 62000, reorderLevel: 10, requiresPrescription: true, isActive: true, stockOnHand: 34),
    Medicine(id: 'm6', name: 'Zyrtec 10mg x10', genericName: 'Cetirizine', dosageForm: DosageForm.tablet, sku: 'CET-10', barcode: '6161100010066', sellingPriceMinor: 28000, reorderLevel: 15, requiresPrescription: false, isActive: true, stockOnHand: 71),
    Medicine(id: 'm7', name: 'Losec 20mg x14', genericName: 'Omeprazole', dosageForm: DosageForm.capsule, sku: 'OME-20', barcode: '6161100010073', sellingPriceMinor: 54000, reorderLevel: 10, requiresPrescription: false, isActive: true, stockOnHand: 0),
    Medicine(id: 'm8', name: 'Vitamin C 1000mg x20', genericName: 'Ascorbic acid', dosageForm: DosageForm.tablet, sku: 'VTC-1000', barcode: '6161100010080', sellingPriceMinor: 36000, reorderLevel: 20, requiresPrescription: false, isActive: true, stockOnHand: 90),
    Medicine(id: 'm9', name: 'Zinc 20mg dispersible x10', genericName: 'Zinc sulfate', dosageForm: DosageForm.tablet, sku: 'ZNC-20', barcode: '6161100010097', sellingPriceMinor: 15000, reorderLevel: 20, requiresPrescription: false, isActive: true, stockOnHand: 120),
    Medicine(id: 'm10', name: 'Ventolin inhaler 100mcg', genericName: 'Salbutamol', dosageForm: DosageForm.inhaler, sku: 'SAL-100', barcode: '6161100010103', sellingPriceMinor: 78000, reorderLevel: 6, requiresPrescription: true, isActive: true, stockOnHand: 12),
    Medicine(id: 'm11', name: 'Coartem 80/480mg x6', genericName: 'Artemether/Lumefantrine', dosageForm: DosageForm.tablet, sku: 'ALU-80', barcode: '6161100010110', sellingPriceMinor: 55000, reorderLevel: 12, requiresPrescription: true, isActive: true, stockOnHand: 4),
    Medicine(id: 'm12', name: 'Voltaren Emulgel 50g', genericName: 'Diclofenac gel', dosageForm: DosageForm.cream, sku: 'DIC-GEL', barcode: '6161100010127', sellingPriceMinor: 89000, reorderLevel: 8, requiresPrescription: false, isActive: true, stockOnHand: 27),
    Medicine(id: 'm13', name: 'Imodium 2mg x12', genericName: 'Loperamide', dosageForm: DosageForm.capsule, sku: 'LOP-2', barcode: '6161100010134', sellingPriceMinor: 41000, reorderLevel: 10, requiresPrescription: false, isActive: true, stockOnHand: 38),
    Medicine(id: 'm14', name: 'Betadine solution 100ml', genericName: 'Povidone iodine', dosageForm: DosageForm.other, sku: 'POV-100', barcode: '6161100010141', sellingPriceMinor: 32500, reorderLevel: 10, requiresPrescription: false, isActive: true, stockOnHand: 46),
    Medicine(id: 'm15', name: 'Benylin cough syrup 100ml', genericName: 'Dextromethorphan', dosageForm: DosageForm.syrup, sku: 'BEN-100', barcode: '6161100010158', sellingPriceMinor: 38000, reorderLevel: 10, requiresPrescription: false, isActive: false, stockOnHand: 0),
  ];
}
