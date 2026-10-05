import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/features/medicines/data/repositories/demo_medicine_repository.dart';
import 'package:pharmacy_pos/features/medicines/domain/entities/medicine.dart';
import 'package:pharmacy_pos/features/medicines/domain/medicine_messages.dart';
import 'package:pharmacy_pos/features/medicines/domain/usecases/get_medicines.dart';
import 'package:pharmacy_pos/features/medicines/domain/usecases/save_medicine.dart';
import 'package:pharmacy_pos/features/medicines/domain/usecases/set_medicine_active.dart';
import 'package:pharmacy_pos/features/medicines/presentation/bloc/medicines_cubit.dart';

MedicineDraft draft({
  String name = 'Test Medicine 10mg',
  String sku = 'TST-10',
  String barcode = '',
  int price = 10000,
  int reorder = 5,
  bool rx = false,
}) {
  return MedicineDraft(
    name: name,
    genericName: 'Testium',
    dosageForm: DosageForm.tablet,
    sku: sku,
    barcode: barcode,
    sellingPriceMinor: price,
    reorderLevel: reorder,
    requiresPrescription: rx,
  );
}

MedicinesCubit buildCubit() {
  final repository = DemoMedicineRepository();
  return MedicinesCubit(
    getMedicines: GetMedicines(repository),
    saveMedicine: SaveMedicine(repository),
    setMedicineActive: SetMedicineActive(repository),
  );
}

void main() {
  group('SaveMedicine', () {
    late SaveMedicine useCase;

    setUp(() => useCase = SaveMedicine(DemoMedicineRepository()));

    Future<String?> failureOf(MedicineDraft d, {String? id}) async {
      final result = await useCase(d, id: id);
      return result is Err<Medicine> ? result.failure.message : null;
    }

    test('creates a medicine with no stock that is active', () async {
      final result = await useCase(draft());
      final medicine = (result as Ok<Medicine>).value;
      expect(medicine.stockOnHand, 0);
      expect(medicine.isActive, isTrue);
      expect(medicine.stockLevel, StockLevel.out);
    });

    test('rejects missing name, missing SKU, zero price and negative reorder level', () async {
      expect(await failureOf(draft(name: ' ')), MedicineMessages.nameMissing);
      expect(await failureOf(draft(sku: '')), MedicineMessages.skuMissing);
      expect(await failureOf(draft(price: 0)), MedicineMessages.priceInvalid);
      expect(await failureOf(draft(reorder: -1)), MedicineMessages.reorderInvalid);
    });

    test('accepts an empty barcode but rejects a malformed one', () async {
      expect(await failureOf(draft(barcode: '')), isNull);
      expect(await failureOf(draft(sku: 'TST-11', barcode: 'ab')), MedicineMessages.barcodeInvalid);
      expect(await failureOf(draft(sku: 'TST-12', barcode: 'no spaces!')), MedicineMessages.barcodeInvalid);
    });

    test('rejects a duplicate SKU or barcode but allows re-saving the same medicine', () async {
      expect(await failureOf(draft(sku: 'par-500')), MedicineMessages.duplicateSku);
      expect(await failureOf(draft(sku: 'NEW-1', barcode: '6161100010011')), MedicineMessages.duplicateBarcode);
      expect(await failureOf(draft(name: 'Panadol 500mg x24', sku: 'PAR-500', barcode: '6161100010011'), id: 'm1'), isNull);
    });
  });

  group('MedicinesCubit', () {
    test('loads the catalogue sorted by name and counts the filters', () async {
      final cubit = buildCubit();
      await cubit.load();
      final names = cubit.state.medicines.map((m) => m.name.toLowerCase()).toList();
      expect(names, [...names]..sort());
      // Seed data: Losec is out of stock (the inactive syrup is not counted),
      // ORS and Coartem are at or below their reorder level.
      expect(cubit.state.count(MedicineFilter.outOfStock), 1);
      expect(cubit.state.count(MedicineFilter.lowStock), 2);
      expect(cubit.state.count(MedicineFilter.inactive), 1);
      await cubit.close();
    });

    test('search matches name, generic, SKU and barcode', () async {
      final cubit = buildCubit();
      await cubit.load();
      cubit.setQuery('paracetamol');
      expect(cubit.state.visible.single.sku, 'PAR-500');
      cubit.setQuery('ibu-400');
      expect(cubit.state.visible.single.name, 'Brufen 400mg x30');
      cubit.setQuery('6161100010103');
      expect(cubit.state.visible.single.sku, 'SAL-100');
      await cubit.close();
    });

    test('saving adds the medicine and keeps the list sorted', () async {
      final cubit = buildCubit();
      await cubit.load();
      final before = cubit.state.medicines.length;
      final error = await cubit.save(draft(name: 'Aaa First Medicine', sku: 'AAA-1'));
      expect(error, isNull);
      expect(cubit.state.medicines.length, before + 1);
      expect(cubit.state.medicines.first.name, 'Aaa First Medicine');
      await cubit.close();
    });

    test('saving returns the message instead of closing on a duplicate SKU', () async {
      final cubit = buildCubit();
      await cubit.load();
      final error = await cubit.save(draft(sku: 'PAR-500'));
      expect(error, MedicineMessages.duplicateSku);
      await cubit.close();
    });

    test('deactivating a medicine moves it to the Inactive filter', () async {
      final cubit = buildCubit();
      await cubit.load();
      final panadol = cubit.state.medicines.firstWhere((m) => m.sku == 'PAR-500');
      await cubit.toggleActive(panadol);
      expect(cubit.state.count(MedicineFilter.inactive), 2);
      cubit.setFilter(MedicineFilter.inactive);
      expect(cubit.state.visible.any((m) => m.sku == 'PAR-500'), isTrue);
      await cubit.close();
    });
  });
}
