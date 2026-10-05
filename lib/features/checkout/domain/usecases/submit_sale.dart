import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../entities/order_totals.dart';
import '../entities/payment.dart';
import '../entities/sale.dart';
import '../entities/sale_type.dart';
import '../repositories/sale_repository.dart';

/// Local validation for fast feedback. The Go backend repeats every check.
class SubmitSale {
  const SubmitSale(this._repository);

  final SaleRepository _repository;

  Future<Result<SaleReceipt>> call(SaleRequest request) {
    final failure = _validate(request);
    if (failure != null) return Future.value(Err<SaleReceipt>(failure));
    return _repository.submit(request);
  }

  Failure? _validate(SaleRequest request) {
    if (request.lines.isEmpty) return const ValidationFailure(AppStrings.errorCartEmpty);

    final needsRx = request.lines.any((line) => line.requiresPrescription);
    if (needsRx && !request.prescriptionVerified) {
      return const ValidationFailure(AppStrings.errorRxNotVerified);
    }

    if (request.discountMinor < 0 || request.discountMinor > request.subtotalMinor) {
      return const ValidationFailure(AppStrings.errorInvalidDiscount);
    }

    final isCredit = request.saleType == SaleType.credit;
    if (isCredit && request.customerId == null) {
      return const ValidationFailure(AppStrings.errorCreditNeedsCustomer);
    }
    if (request.payments.any((p) => p.amountMinor <= 0)) {
      return const ValidationFailure(AppStrings.errorInvalidAmount);
    }

    final total = OrderTotals.fromSubtotal(
      request.subtotalMinor,
      discountMinor: request.discountMinor,
    ).totalMinor;
    final tendered = request.payments.fold(0, (sum, p) => sum + p.amountMinor);
    final nonCash = request.payments
        .where((p) => p.method != PaymentMethod.cash)
        .fold(0, (sum, p) => sum + p.amountMinor);

    if (isCredit) {
      return tendered > total ? const ValidationFailure(AppStrings.errorCreditOverpay) : null;
    }

    if (request.payments.isEmpty) return const ValidationFailure(AppStrings.errorNoPayment);
    if (tendered < total) return const ValidationFailure(AppStrings.errorPaymentShort);
    if (nonCash > total) return const ValidationFailure(AppStrings.errorNonCashOverpay);
    return null;
  }
}
