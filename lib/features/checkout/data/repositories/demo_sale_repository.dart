import '../../../../core/result/result.dart';
import '../../domain/entities/order_totals.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_type.dart';
import '../../domain/repositories/sale_repository.dart';

/// Stand-in that "accepts" every valid sale. Replace with the REST client that
/// POSTs to the Go API with the idempotency key in a header.
class DemoSaleRepository implements SaleRepository {
  static const Duration _latency = Duration(milliseconds: 400);
  static const int _firstReceiptNumber = 1001;
  static const String _receiptPrefix = 'RCP-';

  int _counter = _firstReceiptNumber;
  final Map<String, SaleReceipt> _byKey = {};

  @override
  Future<Result<SaleReceipt>> submit(SaleRequest request) async {
    await Future<void>.delayed(_latency);

    final existing = _byKey[request.idempotencyKey];
    if (existing != null) return Ok(existing);

    final total = OrderTotals.fromSubtotal(
      request.subtotalMinor,
      discountMinor: request.discountMinor,
    ).totalMinor;
    final tendered = request.payments.fold(0, (sum, p) => sum + p.amountMinor);
    final isCredit = request.saleType == SaleType.credit;

    final receipt = SaleReceipt(
      receiptNumber: '$_receiptPrefix${_counter++}',
      totalMinor: total,
      changeDueMinor: !isCredit && tendered > total ? tendered - total : 0,
      amountOnAccountMinor: isCredit ? total - tendered : 0,
      completedAt: DateTime.now(),
    );
    _byKey[request.idempotencyKey] = receipt;
    return Ok(receipt);
  }
}
