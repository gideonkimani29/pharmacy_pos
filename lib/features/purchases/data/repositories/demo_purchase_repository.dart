import '../../../../core/result/result.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/purchase_repository.dart';

class DemoPurchaseRepository implements PurchaseRepository {
  DemoPurchaseRepository({
    List<Purchase> purchases = const [],
    List<Supplier> suppliers = const [],
  })  : _purchases = [...purchases],
        _suppliers = [...suppliers];

  static const Duration _latency = Duration(milliseconds: 300);
  static const String _unknownSupplier = 'Unknown supplier';
  static const String _referencePrefix = 'PUR-';
  static const int _referenceDigits = 4;
  static const int _firstNewNumber = 1;

  final List<Purchase> _purchases = [];
  final List<Supplier> _suppliers;
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

    final supplier = _suppliers.where((s) => s.id == request.supplierId);
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
}
