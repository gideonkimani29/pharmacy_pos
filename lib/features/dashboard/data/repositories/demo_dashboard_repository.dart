import '../../../../core/result/result.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// Fixed sample numbers so the screen can be built before the Go API exists.
/// Replace with a REST-backed repository (GET /dashboard/summary).
class DemoDashboardRepository implements DashboardRepository {
  DemoDashboardRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const Duration _latency = Duration(milliseconds: 300);
  static const int _daysInChart = 7;

  /// KES 38,400 ... KES 28,650 (today, part-day), in minor units.
  static const List<int> _weeklySalesMinor = [
    3840000, 4515000, 4190000, 5230000, 4780000, 6125000, 2865000,
  ];

  final DateTime Function() _clock;

  @override
  Future<Result<DashboardSummary>> load() async {
    await Future<void>.delayed(_latency);

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    DateTime inDays(int days) => today.add(Duration(days: days));

    return Ok(DashboardSummary(
      todaySalesMinor: _weeklySalesMinor.last,
      todayTransactions: 34,
      todayItemsSold: 112,
      creditOutstandingMinor: 8650000,
      weeklySales: [
        for (var i = 0; i < _daysInChart; i++)
          DailySales(date: inDays(i - (_daysInChart - 1)), totalMinor: _weeklySalesMinor[i]),
      ],
      lowStock: const [
        StockAlert(productName: 'Losec 20mg x14', sellableStock: 0, lowStockThreshold: 10),
        StockAlert(productName: 'Coartem 80/480mg x6', sellableStock: 4, lowStockThreshold: 12),
        StockAlert(productName: 'ORS sachet', sellableStock: 8, lowStockThreshold: 25),
        StockAlert(productName: 'Imodium 2mg x12', sellableStock: 9, lowStockThreshold: 10),
      ],
      expiring: [
        ExpiryAlert(productName: 'Aspirin 75mg x28', batchNumber: 'B017', expiryDate: inDays(-6), quantity: 14),
        ExpiryAlert(productName: 'Zyrtec 10mg x10', batchNumber: 'B006', expiryDate: inDays(18), quantity: 71),
        ExpiryAlert(productName: 'Coartem 80/480mg x6', batchNumber: 'B011', expiryDate: inDays(25), quantity: 4),
        ExpiryAlert(productName: 'Brufen 400mg x30', batchNumber: 'B004', expiryDate: inDays(48), quantity: 55),
        ExpiryAlert(productName: 'Amoxil 500mg capsules x21', batchNumber: 'B002', expiryDate: inDays(75), quantity: 62),
        ExpiryAlert(productName: 'Zinc 20mg dispersible x10', batchNumber: 'B009', expiryDate: inDays(88), quantity: 120),
      ],
      topProducts: const [
        TopProduct(name: 'Panadol 500mg x24', unitsSold: 86, revenueMinor: 1548000),
        TopProduct(name: 'Vitamin C 1000mg x20', unitsSold: 41, revenueMinor: 1476000),
        TopProduct(name: 'Brufen 400mg x30', unitsSold: 33, revenueMinor: 1056000),
        TopProduct(name: 'Zinc 20mg dispersible x10', unitsSold: 54, revenueMinor: 810000),
        TopProduct(name: 'ORS sachet', unitsSold: 120, revenueMinor: 420000),
      ],
    ));
  }
}
