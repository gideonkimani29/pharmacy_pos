import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/features/stock/data/repositories/demo_stock_repository.dart';
import 'package:pharmacy_pos/features/stock/domain/entities/stock_batch.dart';
import 'package:pharmacy_pos/features/stock/domain/stock_messages.dart';
import 'package:pharmacy_pos/features/stock/domain/usecases/adjust_stock.dart';
import 'package:pharmacy_pos/features/stock/domain/usecases/get_stock_batches.dart';
import 'package:pharmacy_pos/features/stock/presentation/bloc/stock_cubit.dart';

void main() {
  final today = DateTime(2026, 10, 5, 14, 30);

  StockBatch batch({
    String id = 'b1',
    String medicineId = 'm1',
    int expiresInDays = 200,
    int received = 100,
    int onHand = 50,
    int receivedDaysAgo = 30,
    int reorder = 10,
  }) {
    final midnight = DateTime(today.year, today.month, today.day);
    return StockBatch(
      id: id,
      medicineId: medicineId,
      medicineName: 'Medicine $medicineId',
      batchNumber: 'BN-$id',
      supplierName: 'Supplier',
      receivedOn: midnight.subtract(Duration(days: receivedDaysAgo)),
      expiryDate: midnight.add(Duration(days: expiresInDays)),
      quantityReceived: received,
      quantityOnHand: onHand,
      unitCostMinor: 1000,
      sellingPriceMinor: 1500,
      reorderLevel: reorder,
    );
  }

  group('StockBatch.expiryAt', () {
    test('uses the 30/60/90 day bands and treats the expiry date itself as sellable', () {
      expect(batch(expiresInDays: -1).expiryAt(today), BatchExpiry.expired);
      expect(batch(expiresInDays: 0).expiryAt(today), BatchExpiry.within30);
      expect(batch(expiresInDays: 30).expiryAt(today), BatchExpiry.within30);
      expect(batch(expiresInDays: 31).expiryAt(today), BatchExpiry.within60);
      expect(batch(expiresInDays: 60).expiryAt(today), BatchExpiry.within60);
      expect(batch(expiresInDays: 61).expiryAt(today), BatchExpiry.within90);
      expect(batch(expiresInDays: 90).expiryAt(today), BatchExpiry.within90);
      expect(batch(expiresInDays: 91).expiryAt(today), BatchExpiry.ok);
    });
  });

  group('AdjustStock validation', () {
    late AdjustStock useCase;

    // A fresh repository per test: a successful adjustment changes the stored quantity.
    setUp(() => useCase = AdjustStock(DemoStockRepository(clock: () => today)));

    StockAdjustmentDraft draft({
      int previous = 25,
      int next = 20,
      StockAdjustmentReason reason = StockAdjustmentReason.damaged,
      String note = '',
      String id = 'b6',
    }) {
      return StockAdjustmentDraft(
        batchId: id,
        previousQuantity: previous,
        newQuantity: next,
        reason: reason,
        note: note,
      );
    }

    Future<String?> failureOf(StockAdjustmentDraft d) async {
      final result = await useCase(d);
      return result is Err<StockBatch> ? result.failure.message : null;
    }

    test('rejects a negative quantity and no change', () async {
      expect(await failureOf(draft(next: -1)), StockMessages.quantityInvalid);
      expect(await failureOf(draft(next: 25)), StockMessages.noChange);
    });

    test('write-off reasons can only reduce the quantity; a count correction can raise it', () async {
      expect(await failureOf(draft(next: 30)), StockMessages.mustDecrease);
      expect(await failureOf(draft(next: 30, reason: StockAdjustmentReason.countCorrection)), isNull);
    });

    test('"Other" needs a note', () async {
      expect(await failureOf(draft(reason: StockAdjustmentReason.other)), StockMessages.noteRequired);
      expect(await failureOf(draft(reason: StockAdjustmentReason.other, note: 'Spilled')), isNull);
    });

    test('rejects an adjustment based on a stale quantity', () async {
      expect(await failureOf(draft(previous: 999, next: 5)), StockMessages.changedElsewhere);
    });
  });

  group('StockCubit', () {
    StockCubit build() {
      final repository = DemoStockRepository(clock: () => today);
      return StockCubit(
        getStockBatches: GetStockBatches(repository),
        adjustStock: AdjustStock(repository),
        clock: () => today,
      );
    }

    test('FEFO picks the earliest-expiring batch with stock that has not expired', () async {
      final cubit = build();
      await cubit.load();
      final next = cubit.state.fefoNextBatchIds;
      // Zyrtec has an expired empty batch (b19) and a 18-day batch (b9): b9 sells first.
      expect(next.contains('b9'), isTrue);
      expect(next.contains('b19'), isFalse);
      // Panadol has two sellable batches: the one expiring sooner (b1) goes first.
      expect(next.contains('b1'), isTrue);
      expect(next.contains('b2'), isFalse);
      // The expired Aspirin batch holds stock but is never next.
      expect(next.contains('b18'), isFalse);
      await cubit.close();
    });

    test('expired stock is excluded from sellable units and counted for write-off', () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.expiredUnits, 14);
      final total = cubit.state.batches.fold(0, (sum, b) => sum + b.quantityOnHand);
      expect(cubit.state.sellableUnits, total - 14);
      await cubit.close();
    });

    test('filters: expired shows only expired batches that still hold stock', () async {
      final cubit = build();
      await cubit.load();
      cubit.setFilter(StockFilter.expired);
      expect(cubit.state.visibleBatches.map((b) => b.id), ['b18']);
      cubit.setFilter(StockFilter.empty);
      expect(cubit.state.visibleBatches.map((b) => b.id).toSet(), {'b10', 'b19'});
      await cubit.close();
    });

    test('summaries use sellable stock against the reorder level', () async {
      final cubit = build();
      await cubit.load();
      final byId = {for (final s in cubit.state.summaries) s.medicineId: s};
      expect(byId['m7']!.level, SellableLevel.out); // Losec: only an empty batch
      expect(byId['m3']!.level, SellableLevel.low); // ORS: 8 left, reorder at 25
      expect(byId['m16']!.level, SellableLevel.out); // Aspirin: stock exists but it has expired
      expect(byId['m1']!.level, SellableLevel.ok);
      expect(byId['m1']!.sellableUnits, 140);
      await cubit.close();
    });

    test('writing off an expired batch updates the list and the totals', () async {
      final cubit = build();
      await cubit.load();
      final error = await cubit.adjust(const StockAdjustmentDraft(
        batchId: 'b18',
        previousQuantity: 14,
        newQuantity: 0,
        reason: StockAdjustmentReason.expired,
        note: '',
      ));
      expect(error, isNull);
      expect(cubit.state.expiredUnits, 0);
      expect(cubit.state.batches.firstWhere((b) => b.id == 'b18').quantityOnHand, 0);
      expect(cubit.state.notice, isNotNull);
      await cubit.close();
    });

    test('search matches medicine, batch number and supplier', () async {
      final cubit = build();
      await cubit.load();
      cubit.setQuery('pn2503');
      expect(cubit.state.visibleBatches.single.id, 'b2');
      cubit.setQuery('nairobi generics');
      expect(cubit.state.visibleBatches.every((b) => b.supplierName == 'Nairobi Generics Depot'), isTrue);
      await cubit.close();
    });
  });
}
