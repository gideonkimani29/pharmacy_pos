import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../entities/losses_report.dart';
import '../entities/report_range.dart';
import '../repositories/report_repository.dart';
import '../validate_report_range.dart';

class GetLossesReport {
  const GetLossesReport(this._repository);

  final ReportRepository _repository;

  Future<Result<LossesReport>> call(ReportRange range) {
    final Failure? failure = validateReportRange(range);
    if (failure != null) return Future.value(Err<LossesReport>(failure));
    return _repository.losses(range);
  }
}
