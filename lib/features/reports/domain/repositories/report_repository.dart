import '../../../../core/result/result.dart';
import '../entities/losses_report.dart';
import '../entities/profit_report.dart';
import '../entities/report_range.dart';
import '../entities/sales_report.dart';

abstract interface class ReportRepository {
  Future<Result<SalesReport>> sales(ReportRange range);
  Future<Result<ProfitReport>> profit(ReportRange range);
  Future<Result<LossesReport>> losses(ReportRange range);
}
