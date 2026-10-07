import '../../../core/error/failures.dart';
import 'entities/report_range.dart';
import 'report_messages.dart';

const int maxReportDays = 366;

/// Shared by every report use case. Returns null when the range is fine.
Failure? validateReportRange(ReportRange range) {
  if (range.from.isAfter(range.to)) return const ValidationFailure(ReportMessages.rangeReversed);
  if (range.dayCount > maxReportDays) return const ValidationFailure(ReportMessages.rangeTooLong);
  return null;
}
