import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/features/reports/data/repositories/demo_report_repository.dart';
import 'package:pharmacy_pos/features/reports/domain/entities/losses_report.dart';
import 'package:pharmacy_pos/features/reports/domain/entities/profit_report.dart';
import 'package:pharmacy_pos/features/reports/domain/entities/report_range.dart';
import 'package:pharmacy_pos/features/reports/domain/entities/sales_report.dart';
import 'package:pharmacy_pos/features/reports/domain/report_messages.dart';
import 'package:pharmacy_pos/features/reports/domain/usecases/get_losses_report.dart';
import 'package:pharmacy_pos/features/reports/domain/usecases/get_profit_report.dart';
import 'package:pharmacy_pos/features/reports/domain/usecases/get_sales_report.dart';
import 'package:pharmacy_pos/features/reports/presentation/bloc/reports_cubit.dart';
import 'package:pharmacy_pos/features/reports/presentation/report_csv.dart';
import 'package:pharmacy_pos/features/reports/presentation/report_format.dart';

final DateTime _now = DateTime(2026, 10, 6, 14, 30);

DemoReportRepository _repository() => DemoReportRepository(clock: () => _now);

ReportsCubit _cubit() {
  final repository = _repository();
  return ReportsCubit(
    getSalesReport: GetSalesReport(repository),
    getProfitReport: GetProfitReport(repository),
    getLossesReport: GetLossesReport(repository),
    clock: () => _now,
  );
}

void main() {
  group('ReportRange', () {
    test('ignores the time of day and counts both ends', () {
      final range = ReportRange(from: DateTime(2026, 10, 1, 23, 59), to: DateTime(2026, 10, 6, 0, 1));
      expect(range.from, DateTime(2026, 10, 1));
      expect(range.to, DateTime(2026, 10, 6));
      expect(range.dayCount, 6);
      expect(range.contains(DateTime(2026, 10, 6, 18)), isTrue);
      expect(range.contains(DateTime(2026, 9, 30, 23)), isFalse);
      expect(range.dayAt(2), DateTime(2026, 10, 3));
    });
  });

  group('range validation', () {
    final useCase = GetSalesReport(_repository());

    Future<String?> failureOf(ReportRange range) async {
      final result = await useCase(range);
      return result is Err<SalesReport> ? result.failure.message : null;
    }

    test('rejects a start date after the end date', () async {
      expect(
        await failureOf(ReportRange(from: DateTime(2026, 10, 6), to: DateTime(2026, 10, 1))),
        ReportMessages.rangeReversed,
      );
    });

    test('allows up to 366 days and rejects more', () async {
      final end = DateTime(2026, 10, 6);
      expect(await failureOf(ReportRange(from: DateTime(2026, 10, 6 - 365), to: end)), isNull);
      expect(await failureOf(ReportRange(from: DateTime(2026, 10, 6 - 366), to: end)), ReportMessages.rangeTooLong);
    });
  });

  group('demo reports agree with each other', () {
    final range = ReportRange(from: DateTime(2026, 9, 7), to: DateTime(2026, 10, 6));

    test('sales: one row per day, net is gross minus discount, payments add up to net', () async {
      final report = (await _repository().sales(range) as Ok<SalesReport>).value;
      expect(report.days.length, 30);
      expect(report.netMinor, report.grossMinor - report.discountMinor);
      expect(report.byPayment.fold(0, (sum, p) => sum + p.amountMinor), report.netMinor);
      expect(report.days.first.date, DateTime(2026, 9, 7));
      expect(report.days.last.date, DateTime(2026, 10, 6));
      expect(report.averageSaleMinor, report.netMinor ~/ report.transactions);
    });

    test('profit: revenue equals net sales and cost is below revenue', () async {
      final repository = _repository();
      final sales = (await repository.sales(range) as Ok<SalesReport>).value;
      final profit = (await repository.profit(range) as Ok<ProfitReport>).value;
      expect(profit.revenueMinor, sales.netMinor);
      expect(profit.costMinor, lessThan(profit.revenueMinor));
      expect(profit.profitMinor, profit.revenueMinor - profit.costMinor);
      final byProfit = profit.byProfit.map((p) => p.profitMinor).toList();
      expect(byProfit, [...byProfit]..sort((a, b) => b.compareTo(a)));
    });

    test('the same period always gives the same figures', () async {
      final first = (await _repository().sales(range) as Ok<SalesReport>).value;
      final second = (await _repository().sales(range) as Ok<SalesReport>).value;
      expect(first, second);
    });

    test('losses: only events inside the period, with totals by reason', () async {
      final repository = _repository();
      final week = ReportRange(from: DateTime(2026, 9, 30), to: DateTime(2026, 10, 6));
      final weekReport = (await repository.losses(week) as Ok<LossesReport>).value;
      expect(weekReport.rows.length, 1);
      expect(weekReport.totalLossMinor, 112000); // 14 Aspirin at KES 80

      final month = (await repository.losses(range) as Ok<LossesReport>).value;
      expect(month.rows.length, 4);
      expect(month.totalLossMinor, 1184000);
      expect(month.lossFor(LossReason.expired), 1102000);
      expect(month.lossFor(LossReason.damaged), 72000);
      expect(month.lossFor(LossReason.countShortage), 10000);
      expect(month.rows.first.date.isAfter(month.rows.last.date), isTrue); // newest first
    });
  });

  group('ReportFormat', () {
    test('percent uses integer maths and one decimal', () {
      expect(ReportFormat.percent(348, 1000), '34.8%');
      expect(ReportFormat.percent(1, 3), '33.3%');
      expect(ReportFormat.percent(-50, 1000), '-5.0%');
      expect(ReportFormat.percent(0, 10), '0.0%');
      expect(ReportFormat.percent(5, 0), '0.0%');
    });

    test('isoDate pads month and day', () {
      expect(ReportFormat.isoDate(DateTime(2026, 3, 4)), '2026-03-04');
    });
  });

  group('ReportCsv', () {
    test('quotes only values that need it', () {
      expect(ReportCsv.cell('plain'), 'plain');
      expect(ReportCsv.cell('a,b'), '"a,b"');
      expect(ReportCsv.cell('say "hi"'), '"say ""hi"""');
    });

    test('sales CSV has a header, one line per day, a total, and the payment split, with plain amounts', () async {
      final range = ReportRange(from: DateTime(2026, 9, 30), to: DateTime(2026, 10, 6));
      final report = (await _repository().sales(range) as Ok<SalesReport>).value;
      final lines = ReportCsv.sales(report).split('\n');
      expect(lines.first, 'Date,Sales,Items,Gross,Discount,Net');
      expect(lines.length, 7 + 8); // header + 7 days + total + blank + split header + 4 methods
      expect(lines[1].startsWith('2026-09-30,'), isTrue);
      expect(lines[8].startsWith('Total,'), isTrue);
      expect(ReportCsv.sales(report).contains('KES'), isFalse);
    });
  });

  group('ReportsCubit', () {
    test('presets map to the right days', () {
      ReportRange rangeFor(RangePreset p) => ReportsCubit.rangeFor(p, _now);
      expect(rangeFor(RangePreset.today), ReportRange(from: DateTime(2026, 10, 6), to: DateTime(2026, 10, 6)));
      expect(rangeFor(RangePreset.last7), ReportRange(from: DateTime(2026, 9, 30), to: DateTime(2026, 10, 6)));
      expect(rangeFor(RangePreset.last30), ReportRange(from: DateTime(2026, 9, 7), to: DateTime(2026, 10, 6)));
      expect(rangeFor(RangePreset.thisMonth), ReportRange(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 6)));
    });

    test('starts on the last 7 days and loads all three reports', () async {
      final cubit = _cubit();
      expect(cubit.state.preset, RangePreset.last7);
      await cubit.load();
      expect(cubit.state.status, ReportsStatus.loaded);
      expect(cubit.state.sales!.days.length, 7);
      expect(cubit.state.profit, isNotNull);
      expect(cubit.state.losses, isNotNull);
      await cubit.close();
    });

    test('choosing a preset changes the range and reloads', () async {
      final cubit = _cubit();
      await cubit.load();
      await cubit.setPreset(RangePreset.last30);
      expect(cubit.state.preset, RangePreset.last30);
      expect(cubit.state.sales!.days.length, 30);
      expect(cubit.state.losses!.rows.length, 4);
      await cubit.close();
    });

    test('a custom range is used as given', () async {
      final cubit = _cubit();
      await cubit.setCustomRange(ReportRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31)));
      expect(cubit.state.preset, RangePreset.custom);
      expect(cubit.state.sales!.days.length, 31);
      await cubit.close();
    });

    test('an invalid range fails but keeps the figures already on screen', () async {
      final cubit = _cubit();
      await cubit.load();
      await cubit.setCustomRange(ReportRange(from: DateTime(2026, 10, 6), to: DateTime(2026, 10, 1)));
      expect(cubit.state.status, ReportsStatus.failure);
      expect(cubit.state.failure!.message, ReportMessages.rangeReversed);
      expect(cubit.state.sales, isNotNull);
      await cubit.close();
    });

    test('CSV follows the tab and is null before anything has loaded', () async {
      final cubit = _cubit();
      expect(cubit.currentCsv(), isNull);
      await cubit.load();
      expect(cubit.currentCsv()!.startsWith('Date,Sales'), isTrue);
      cubit.setTab(ReportTab.profit);
      expect(cubit.currentCsv()!.startsWith('Product,Units'), isTrue);
      cubit.setTab(ReportTab.losses);
      expect(cubit.currentCsv()!.startsWith('Date,Medicine'), isTrue);
      await cubit.close();
    });

    test('announce raises a notice', () async {
      final cubit = _cubit();
      cubit.announce('Hello');
      expect(cubit.state.notice!.message, 'Hello');
      await cubit.close();
    });
  });
}
