import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_config.dart';

class OrderTotals extends Equatable {
  const OrderTotals({
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
  });

  /// Discount is clamped to [0, subtotal]; tax applies to the discounted amount.
  factory OrderTotals.fromSubtotal(int subtotalMinor, {int discountMinor = 0}) {
    final discount = discountMinor < 0
        ? 0
        : (discountMinor > subtotalMinor ? subtotalMinor : discountMinor);
    const half = AppConfig.basisPointsDenominator ~/ 2;
    final taxable = subtotalMinor - discount;
    final tax = (taxable * AppConfig.taxRateBasisPoints + half) ~/ AppConfig.basisPointsDenominator;
    return OrderTotals(subtotalMinor: subtotalMinor, discountMinor: discount, taxMinor: tax);
  }

  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;

  int get totalMinor => subtotalMinor - discountMinor + taxMinor;

  @override
  List<Object?> get props => [subtotalMinor, discountMinor, taxMinor];
}
