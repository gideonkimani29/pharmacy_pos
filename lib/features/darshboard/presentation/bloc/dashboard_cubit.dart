import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/get_dashboard_summary.dart';

enum DashboardStatus { loading, loaded, failure }

class DashboardState extends Equatable {
  const DashboardState({this.status = DashboardStatus.loading, this.summary, this.failure});

  final DashboardStatus status;

  /// Kept across refreshes so the screen does not blank out while reloading.
  final DashboardSummary? summary;
  final Failure? failure;

  @override
  List<Object?> get props => [status, summary, failure];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required GetDashboardSummary getDashboardSummary})
      : _getDashboardSummary = getDashboardSummary,
        super(const DashboardState());

  final GetDashboardSummary _getDashboardSummary;

  Future<void> load() async {
    emit(DashboardState(status: DashboardStatus.loading, summary: state.summary));
    final result = await _getDashboardSummary();
    switch (result) {
      case Ok<DashboardSummary>(:final value):
        emit(DashboardState(status: DashboardStatus.loaded, summary: value));
      case Err<DashboardSummary>(:final failure):
        emit(DashboardState(
          status: DashboardStatus.failure,
          summary: state.summary,
          failure: failure,
        ));
    }
  }
}
