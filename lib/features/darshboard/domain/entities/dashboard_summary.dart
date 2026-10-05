import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_config.dart';

enum ExpiryBand { expired, within30, within60, within90 }

class DailySales extends Equatable {
  const DailySales({required this.date, required this.totalMinor});

  final DateTime date;
  final int totalMinor;

  @override
  List<Object?> get props => [date, totalMinor];
}

class StockAlert extends Equatable {
  const StockAlert({
    required this.productName,
    required this.sellableStock,
    required this.lowStockThreshold,
  });

  final String productName;
  final int sellableStock;
  final int lowStockThreshold;

  bool get isOutOfStock => sellableStock <= 0;

  @override
  List<Object?> get props => [productName, sellableStock, lowStockThreshold];
}

class ExpiryAlert extends Equatable {
  const ExpiryAlert({
    required this.productName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
  });

  final String productName;
  final String batchNumber;
  final DateTime expiryDate;
  final int quantity;

  /// Null when the batch expires more than 90 days from [now].
  ExpiryBand? band(DateTime now) {
    if (expiryDate.isBefore(now)) return ExpiryBand.expired;
    final days = expiryDate.difference(now).inDays;
    if (days <= AppConfig.expiryCriticalDays) return ExpiryBand.within30;
    if (days <= AppConfig.expiryWarningDays) return ExpiryBand.within60;
    if (days <= AppConfig.expiryNoticeDays) return ExpiryBand.within90;
    return null;
  }

  @override
  List<Object?> get props => [productName, batchNumber, expiryDate, quantity];
}

class TopProduct extends Equatable {
  const TopProduct({required this.name, required this.unitsSold, required this.revenueMinor});

  final String name;
  final int unitsSold;
  final int revenueMinor;

  @override
  List<Object?> get props => [name, unitsSold, revenueMinor];
}

class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.todaySalesMinor,
    required this.todayTransactions,
    required this.todayItemsSold,
    required this.creditOutstandingMinor,
    required this.weeklySales,
    required this.lowStock,
    required this.expiring,
    required this.topProducts,
  });

  final int todaySalesMinor;
  final int todayTransactions;
  final int todayItemsSold;
  final int creditOutstandingMinor;
  final List<DailySales> weeklySales;
  final List<StockAlert> lowStock;
  final List<ExpiryAlert> expiring;
  final List<TopProduct> topProducts;

  int get averageSaleMinor => todayTransactions == 0 ? 0 : todaySalesMinor ~/ todayTransactions;

  int expiringCount(ExpiryBand band, DateTime now) =>
      expiring.where((alert) => alert.band(now) == band).length;

  @override
  List<Object?> get props => [
        todaySalesMinor,
        todayTransactions,
        todayItemsSold,
        creditOutstandingMinor,
        weeklySales,
        lowStock,
        expiring,
        topProducts,
      ];
}
