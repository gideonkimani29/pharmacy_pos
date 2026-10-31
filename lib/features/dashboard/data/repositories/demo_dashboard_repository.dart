import '../../../../core/result/result.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DemoDashboardRepository implements DashboardRepository {
  static const Duration _latency = Duration(milliseconds: 300);

  @override
  Future<Result<DashboardSummary>> load() async {
    await Future<void>.delayed(_latency);
    return const Ok(DashboardSummary(
      todaySalesMinor: 0,
      todayTransactions: 0,
      todayItemsSold: 0,
      creditOutstandingMinor: 0,
      weeklySales: [],
      lowStock: [],
      expiring: [],
      topProducts: [],
    ));
  }
}
