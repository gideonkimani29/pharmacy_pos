import '../../../../core/result/result.dart';
import '../entities/sale.dart';

abstract interface class SaleRepository {
  Future<Result<SaleReceipt>> submit(SaleRequest request);
}
