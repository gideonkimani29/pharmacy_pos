import 'package:equatable/equatable.dart';

import 'report_range.dart';

class ProductProfit extends Equatable {
  const ProductProfit({
    required this.name,
    required this.unitsSold,
    required this.revenueMinor,
    required this.costMinor,
  });

  final String name;
  final int unitsSold;
  final int revenueMinor;

  /// Cost of the batches that were actually sold (FEFO), not today's price.
  final int costMinor;

  int get profitMinor => revenueMinor - costMinor;

  @override
  List<Object?> get props => [name, unitsSold, revenueMinor, costMinor];
}

class ProfitReport extends Equatable {
  const ProfitReport({required this.range, required this.products});

  final ReportRange range;
  final List<ProductProfit> products;

  int get revenueMinor => products.fold(0, (sum, p) => sum + p.revenueMinor);
  int get costMinor => products.fold(0, (sum, p) => sum + p.costMinor);
  int get profitMinor => revenueMinor - costMinor;

  /// Most profitable first.
  List<ProductProfit> get byProfit => [...products]..sort((a, b) => b.profitMinor.compareTo(a.profitMinor));

  @override
  List<Object?> get props => [range, products];
}
