import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../entities/report_range.dart';
import '../entities/sales_report.dart';
import '../repositories/report_repository.dart';
import '../validate_report_range.dart';

class GetSalesReport {
  const GetSalesReport(this._repository);

  final ReportRepository _repository;

  Future<Result<SalesReport>> call(ReportRange range) {
    final Failure? failure = validateReportRange(range);
    if (failure != null) return Future.value(Err<SalesReport>(failure));
    return _repository.sales(range);
  }
}
