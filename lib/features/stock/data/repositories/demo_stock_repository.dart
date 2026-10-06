import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/stock_batch.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/stock_messages.dart';

/// In-memory batches so the module can be built before the Go API exists.
/// Replace with a REST-backed repository.
class DemoStockRepository implements StockRepository {
  DemoStockRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _batches.addAll(_seed(_clock()));
  }

  static const Duration _latency = Duration(milliseconds: 250);

  final DateTime Function() _clock;
  final List<StockBatch> _batches = [];

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

  static List<StockBatch> _seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime inDays(int days) => today.add(Duration(days: days));

    const eldoret = 'Eldoret Pharma Wholesalers';
    const highlands = 'Highlands Medical Distributors';
    const riftValley = 'Rift Valley Pharma Supplies';
    const nairobi = 'Nairobi Generics Depot';

    StockBatch batch(
      String id,
      String medicineId,
      String medicine,
      String number,
      String supplier,
      int receivedDaysAgo,
      int expiresInDays,
      int received,
      int onHand,
      int cost,
      int price,
      int reorder,
    ) {
      return StockBatch(
        id: id,
        medicineId: medicineId,
        medicineName: medicine,
        batchNumber: number,
        supplierName: supplier,
        receivedOn: inDays(-receivedDaysAgo),
        expiryDate: inDays(expiresInDays),
        quantityReceived: received,
        quantityOnHand: onHand,
        unitCostMinor: cost,
        sellingPriceMinor: price,
        reorderLevel: reorder,
      );
    }

    return [
      batch('b1', 'm1', 'Panadol 500mg x24', 'PN2401', eldoret, 150, 420, 120, 60, 12000, 18000, 20),
      batch('b2', 'm1', 'Panadol 500mg x24', 'PN2503', eldoret, 30, 600, 80, 80, 12500, 18000, 20),
      batch('b3', 'm2', 'Amoxil 500mg capsules x21', 'AX2412', riftValley, 120, 75, 60, 22, 30000, 45000, 15),
      batch('b4', 'm2', 'Amoxil 500mg capsules x21', 'AX2506', riftValley, 20, 400, 60, 40, 31000, 45000, 15),
      batch('b5', 'm3', 'ORS sachet', 'OR2501', highlands, 90, 210, 100, 8, 2000, 3500, 25),
      batch('b6', 'm4', 'Brufen 400mg x30', 'BR2410', highlands, 140, 48, 60, 25, 21000, 32000, 15),
      batch('b7', 'm4', 'Brufen 400mg x30', 'BR2504', highlands, 25, 380, 60, 30, 21500, 32000, 15),
      batch('b8', 'm5', 'Glucophage 500mg x60', 'GL2502', nairobi, 60, 300, 60, 34, 41000, 62000, 10),
      batch('b9', 'm6', 'Zyrtec 10mg x10', 'ZY2411', eldoret, 130, 18, 100, 71, 17000, 28000, 15),
      batch('b10', 'm7', 'Losec 20mg x14', 'OM2409', riftValley, 110, 160, 50, 0, 36000, 54000, 10),
      batch('b11', 'm8', 'Vitamin C 1000mg x20', 'VC2503', eldoret, 45, 600, 120, 90, 24000, 36000, 20),
      batch('b12', 'm9', 'Zinc 20mg dispersible x10', 'ZN2412', highlands, 100, 88, 200, 120, 9500, 15000, 20),
      batch('b13', 'm10', 'Ventolin inhaler 100mcg', 'VT2501', nairobi, 70, 160, 20, 12, 52000, 78000, 6),
      batch('b14', 'm11', 'Coartem 80/480mg x6', 'CO2410', riftValley, 115, 25, 40, 4, 36000, 55000, 12),
      batch('b15', 'm12', 'Voltaren Emulgel 50g', 'VO2503', nairobi, 55, 380, 40, 27, 60000, 89000, 8),
      batch('b16', 'm13', 'Imodium 2mg x12', 'IM2504', eldoret, 35, 240, 50, 38, 27000, 41000, 10),
      batch('b17', 'm14', 'Betadine solution 100ml', 'BE2505', highlands, 28, 510, 60, 46, 21000, 32500, 10),
      batch('b18', 'm16', 'Aspirin 75mg x28', 'AS2308', riftValley, 300, -6, 100, 14, 8000, 15000, 10),
      batch('b19', 'm6', 'Zyrtec 10mg x10', 'ZY2312', eldoret, 400, -40, 60, 0, 16500, 28000, 15),
    ];
  }
}
