import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../entities/profit_report.dart';
import '../entities/report_range.dart';
import '../repositories/report_repository.dart';
import '../validate_report_range.dart';

class GetProfitReport {
  const GetProfitReport(this._repository);

  final ReportRepository _repository;

  Future<Result<ProfitReport>> call(ReportRange range) {
    final Failure? failure = validateReportRange(range);
    if (failure != null) return Future.value(Err<ProfitReport>(failure));
    return _repository.profit(range);
  }
}
