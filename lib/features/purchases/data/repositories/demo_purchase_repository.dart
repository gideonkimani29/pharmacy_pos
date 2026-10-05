import '../../../../core/result/result.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/repositories/purchase_repository.dart';
import 'demo_supplier_repository.dart';

/// In-memory purchases so the module can be built before the Go API exists.
/// Replace with a REST-backed repository.
class DemoPurchaseRepository implements PurchaseRepository {
  DemoPurchaseRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _purchases.addAll(_seed(_clock()));
  }

  static const Duration _latency = Duration(milliseconds: 300);
  static const String _unknownSupplier = 'Unknown supplier';
  static const String _referencePrefix = 'PUR-';
  static const int _referenceDigits = 4;
  static const int _firstNewNumber = 5;

  final DateTime Function() _clock;
  final List<Purchase> _purchases = [];
  final Map<String, Purchase> _byKey = {};
  int _counter = _firstNewNumber;

  @override
  Future<Result<List<Purchase>>> list() async {
    await Future<void>.delayed(_latency);
    final sorted = [..._purchases]..sort((a, b) => b.receivedOn.compareTo(a.receivedOn));
    return Ok(sorted);
  }

  @override
  Future<Result<Purchase>> record(PurchaseRequest request) async {
    await Future<void>.delayed(_latency);

    final existing = _byKey[request.idempotencyKey];
    if (existing != null) return Ok(existing);

    final supplier = DemoSupplierRepository.suppliers.where((s) => s.id == request.supplierId);
    final number = (_counter++).toString().padLeft(_referenceDigits, '0');
    final purchase = Purchase(
      id: 'pu$number',
      reference: '$_referencePrefix$number',
      supplierName: supplier.isEmpty ? _unknownSupplier : supplier.first.name,
      invoiceNumber: request.invoiceNumber.trim(),
      receivedOn: request.receivedOn,
      paymentStatus: request.paymentStatus,
      lineCount: request.lines.length,
      unitCount: request.unitCount,
      totalMinor: request.totalMinor,
    );
    _purchases.add(purchase);
    _byKey[request.idempotencyKey] = purchase;
    return Ok(purchase);
  }

  static List<Purchase> _seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime ago(int days) => today.subtract(Duration(days: days));
    return [
      Purchase(id: 'pu0004', reference: 'PUR-0004', supplierName: 'Eldoret Pharma Wholesalers', invoiceNumber: 'EPW-88213', receivedOn: ago(2), paymentStatus: PurchasePaymentStatus.paid, lineCount: 6, unitCount: 480, totalMinor: 18640000),
      Purchase(id: 'pu0003', reference: 'PUR-0003', supplierName: 'Highlands Medical Distributors', invoiceNumber: 'HMD-4471', receivedOn: ago(9), paymentStatus: PurchasePaymentStatus.onCredit, lineCount: 4, unitCount: 220, totalMinor: 9280000),
      Purchase(id: 'pu0002', reference: 'PUR-0002', supplierName: 'Rift Valley Pharma Supplies', invoiceNumber: 'RVP-20931', receivedOn: ago(16), paymentStatus: PurchasePaymentStatus.paid, lineCount: 8, unitCount: 640, totalMinor: 24350000),
      Purchase(id: 'pu0001', reference: 'PUR-0001', supplierName: 'Nairobi Generics Depot', invoiceNumber: 'NGD-1180', receivedOn: ago(30), paymentStatus: PurchasePaymentStatus.onCredit, lineCount: 3, unitCount: 150, totalMinor: 5460000),
    ];
  }
}
