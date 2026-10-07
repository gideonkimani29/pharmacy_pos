import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/losses_report.dart';
import '../../domain/entities/profit_report.dart';
import '../../domain/entities/report_range.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/usecases/get_losses_report.dart';
import '../../domain/usecases/get_profit_report.dart';
import '../../domain/usecases/get_sales_report.dart';
import '../report_csv.dart';
import '../reports_constants.dart';

enum ReportsStatus { loading, loaded, failure }

enum ReportTab { sales, profit, losses }

enum RangePreset { today, last7, last30, thisMonth, custom }

class ReportsNotice extends Equatable {
  const ReportsNotice({required this.id, required this.message});

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

class ReportsState extends Equatable {
  const ReportsState({
    required this.range,
    this.preset = RangePreset.last7,
    this.tab = ReportTab.sales,
    this.status = ReportsStatus.loading,
    this.sales,
    this.profit,
    this.losses,
    this.failure,
    this.notice,
  });

  final ReportRange range;
  final RangePreset preset;
  final ReportTab tab;
  final ReportsStatus status;
  final SalesReport? sales;
  final ProfitReport? profit;
  final LossesReport? losses;
  final Failure? failure;
  final ReportsNotice? notice;

  ReportsState copyWith({
    ReportRange? range,
    RangePreset? preset,
    ReportTab? tab,
    ReportsStatus? status,
    ReportsNotice? notice,
  }) {
    return ReportsState(
      range: range ?? this.range,
      preset: preset ?? this.preset,
      tab: tab ?? this.tab,
      status: status ?? this.status,
      sales: sales,
      profit: profit,
      losses: losses,
      failure: failure,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [range, preset, tab, status, sales, profit, losses, failure, notice];
}

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit({
    required GetSalesReport getSalesReport,
    required GetProfitReport getProfitReport,
    required GetLossesReport getLossesReport,
    DateTime Function()? clock,
  })  : _getSalesReport = getSalesReport,
        _getProfitReport = getProfitReport,
        _getLossesReport = getLossesReport,
        _clock = clock ?? DateTime.now,
        super(ReportsState(range: rangeFor(RangePreset.last7, (clock ?? DateTime.now)())));

  final GetSalesReport _getSalesReport;
  final GetProfitReport _getProfitReport;
  final GetLossesReport _getLossesReport;
  final DateTime Function() _clock;
  int _noticeSequence = 0;

  static const int _lastWeekDays = 7;
  static const int _lastMonthDays = 30;

  /// The range a preset stands for on the day [now]. [RangePreset.custom] has
  /// no fixed range (the user picks it), so it maps to today.
  static ReportRange rangeFor(RangePreset preset, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime daysBack(int days) => DateTime(today.year, today.month, today.day - days);
    return switch (preset) {
      RangePreset.today || RangePreset.custom => ReportRange(from: today, to: today),
      RangePreset.last7 => ReportRange(from: daysBack(_lastWeekDays - 1), to: today),
      RangePreset.last30 => ReportRange(from: daysBack(_lastMonthDays - 1), to: today),
      RangePreset.thisMonth => ReportRange(from: DateTime(today.year, today.month, 1), to: today),
    };
  }

  void _notify(String message) {
    emit(state.copyWith(notice: ReportsNotice(id: ++_noticeSequence, message: message)));
  }

  /// Loads all three reports for the current range in parallel.
  Future<void> load() async {
    final requested = state.range;
    emit(state.copyWith(status: ReportsStatus.loading));

    final salesFuture = _getSalesReport(requested);
    final profitFuture = _getProfitReport(requested);
    final lossesFuture = _getLossesReport(requested);
    final sales = await salesFuture;
    final profit = await profitFuture;
    final losses = await lossesFuture;

    // The user may have picked another period while this one was loading.
    if (isClosed || state.range != requested) return;

    Failure? failure;
    if (sales is Err<SalesReport>) {
      failure = sales.failure;
    } else if (profit is Err<ProfitReport>) {
      failure = profit.failure;
    } else if (losses is Err<LossesReport>) {
      failure = losses.failure;
    }

    if (failure != null) {
      emit(ReportsState(
        range: state.range,
        preset: state.preset,
        tab: state.tab,
        status: ReportsStatus.failure,
        sales: state.sales,
        profit: state.profit,
        losses: state.losses,
        failure: failure,
        notice: state.notice,
      ));
      return;
    }

    emit(ReportsState(
      range: state.range,
      preset: state.preset,
      tab: state.tab,
      status: ReportsStatus.loaded,
      sales: (sales as Ok<SalesReport>).value,
      profit: (profit as Ok<ProfitReport>).value,
      losses: (losses as Ok<LossesReport>).value,
      notice: state.notice,
    ));
  }

  Future<void> setPreset(RangePreset preset) async {
    if (preset == RangePreset.custom) return;
    emit(state.copyWith(preset: preset, range: rangeFor(preset, _clock())));
    await load();
  }

  Future<void> setCustomRange(ReportRange range) async {
    emit(state.copyWith(preset: RangePreset.custom, range: range));
    await load();
  }

  void setTab(ReportTab tab) => emit(state.copyWith(tab: tab));

  /// Lets the UI show a message through the same channel as the cubit's own.
  void announce(String message) => _notify(message);

  /// CSV for the report on screen, or null when it has not loaded yet.
  String? currentCsv() => switch (state.tab) {
        ReportTab.sales => state.sales == null ? null : ReportCsv.sales(state.sales!),
        ReportTab.profit => state.profit == null ? null : ReportCsv.profit(state.profit!),
        ReportTab.losses => state.losses == null ? null : ReportCsv.losses(state.losses!),
      };

  /// Name of the report on screen, for the "copied" message.
  String get currentReportName => switch (state.tab) {
        ReportTab.sales => ReportsStrings.tabSales,
        ReportTab.profit => ReportsStrings.tabProfit,
        ReportTab.losses => ReportsStrings.tabLosses,
      };
}
