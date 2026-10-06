import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/stock_batch.dart';
import '../../domain/usecases/adjust_stock.dart';
import '../../domain/usecases/get_stock_batches.dart';
import '../stock_constants.dart';

enum StockStatus { loading, loaded, failure }

enum StockView { batches, medicines }

enum StockFilter { all, expired, within30, within60, within90, empty }

enum SellableLevel { out, low, ok }

class StockNotice extends Equatable {
  const StockNotice({required this.id, required this.message});

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

/// One row of the "By medicine" view.
class MedicineStockSummary extends Equatable {
  const MedicineStockSummary({
    required this.medicineId,
    required this.name,
    required this.sellableUnits,
    required this.totalUnits,
    required this.batchCount,
    required this.reorderLevel,
    this.nextExpiry,
  });

  final String medicineId;
  final String name;

  /// Units in batches that have not expired.
  final int sellableUnits;
  final int totalUnits;
  final int batchCount;
  final int reorderLevel;

  /// Expiry of the batch FEFO will sell first. Null when nothing is sellable.
  final DateTime? nextExpiry;

  SellableLevel get level {
    if (sellableUnits <= 0) return SellableLevel.out;
    if (sellableUnits <= reorderLevel) return SellableLevel.low;
    return SellableLevel.ok;
  }

  @override
  List<Object?> get props =>
      [medicineId, name, sellableUnits, totalUnits, batchCount, reorderLevel, nextExpiry];
}

class StockState extends Equatable {
  const StockState({
    required this.asOf,
    this.status = StockStatus.loading,
    this.batches = const [],
    this.query = '',
    this.filter = StockFilter.all,
    this.view = StockView.batches,
    this.failure,
    this.notice,
  });

  /// "Today" for every expiry calculation on screen. Set when the data loads.
  final DateTime asOf;
  final StockStatus status;
  final List<StockBatch> batches;
  final String query;
  final StockFilter filter;
  final StockView view;
  final Failure? failure;
  final StockNotice? notice;

  bool _holdsStock(StockBatch b) => b.quantityOnHand > 0;

  bool _matchesFilter(StockBatch b, StockFilter filter) {
    final expiry = b.expiryAt(asOf);
    return switch (filter) {
      StockFilter.all => true,
      StockFilter.expired => _holdsStock(b) && expiry == BatchExpiry.expired,
      StockFilter.within30 => _holdsStock(b) && expiry == BatchExpiry.within30,
      StockFilter.within60 => _holdsStock(b) && expiry == BatchExpiry.within60,
      StockFilter.within90 => _holdsStock(b) && expiry == BatchExpiry.within90,
      StockFilter.empty => b.isDepleted,
    };
  }

  bool _matchesQuery(StockBatch b) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return b.medicineName.toLowerCase().contains(needle) ||
        b.batchNumber.toLowerCase().contains(needle) ||
        b.supplierName.toLowerCase().contains(needle);
  }

  int count(StockFilter filter) => batches.where((b) => _matchesFilter(b, filter)).length;

  /// Earliest-expiring batches first, then oldest received.
  List<StockBatch> get visibleBatches {
    final rows = batches.where((b) => _matchesFilter(b, filter) && _matchesQuery(b)).toList()
      ..sort((a, b) {
        final byExpiry = a.expiryDate.compareTo(b.expiryDate);
        return byExpiry != 0 ? byExpiry : a.receivedOn.compareTo(b.receivedOn);
      });
    return rows;
  }

  /// Ids of the batch FEFO sells first for each medicine.
  Set<String> get fefoNextBatchIds {
    final next = <String, StockBatch>{};
    for (final b in batches) {
      if (!_holdsStock(b) || b.expiryAt(asOf) == BatchExpiry.expired) continue;
      final current = next[b.medicineId];
      final earlier = current == null ||
          b.expiryDate.isBefore(current.expiryDate) ||
          (b.expiryDate == current.expiryDate && b.receivedOn.isBefore(current.receivedOn));
      if (earlier) next[b.medicineId] = b;
    }
    return next.values.map((b) => b.id).toSet();
  }

  List<MedicineStockSummary> get summaries {
    final byMedicine = <String, List<StockBatch>>{};
    for (final b in batches) {
      byMedicine.putIfAbsent(b.medicineId, () => []).add(b);
    }
    final fefoIds = fefoNextBatchIds;
    final needle = query.trim().toLowerCase();

    final rows = <MedicineStockSummary>[];
    for (final group in byMedicine.values) {
      final first = group.first;
      if (needle.isNotEmpty && !first.medicineName.toLowerCase().contains(needle)) continue;

      final sellable = group
          .where((b) => b.expiryAt(asOf) != BatchExpiry.expired)
          .fold(0, (sum, b) => sum + b.quantityOnHand);
      final next = group.where((b) => fefoIds.contains(b.id));
      rows.add(MedicineStockSummary(
        medicineId: first.medicineId,
        name: first.medicineName,
        sellableUnits: sellable,
        totalUnits: group.fold(0, (sum, b) => sum + b.quantityOnHand),
        batchCount: group.where(_holdsStock).length,
        reorderLevel: first.reorderLevel,
        nextExpiry: next.isEmpty ? null : next.first.expiryDate,
      ));
    }
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  int get sellableUnits => batches
      .where((b) => b.expiryAt(asOf) != BatchExpiry.expired)
      .fold(0, (sum, b) => sum + b.quantityOnHand);
  int get stockValueMinor => batches.fold(0, (sum, b) => sum + b.valueAtCostMinor);
  int get expiringBatchCount =>
      count(StockFilter.within30) + count(StockFilter.within60) + count(StockFilter.within90);
  int get expiredUnits => batches
      .where((b) => b.expiryAt(asOf) == BatchExpiry.expired)
      .fold(0, (sum, b) => sum + b.quantityOnHand);

  StockState copyWith({
    DateTime? asOf,
    StockStatus? status,
    List<StockBatch>? batches,
    String? query,
    StockFilter? filter,
    StockView? view,
    Failure? failure,
    StockNotice? notice,
  }) {
    return StockState(
      asOf: asOf ?? this.asOf,
      status: status ?? this.status,
      batches: batches ?? this.batches,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      view: view ?? this.view,
      failure: failure ?? this.failure,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [asOf, status, batches, query, filter, view, failure, notice];
}

class StockCubit extends Cubit<StockState> {
  StockCubit({
    required GetStockBatches getStockBatches,
    required AdjustStock adjustStock,
    DateTime Function()? clock,
  })  : _getStockBatches = getStockBatches,
        _adjustStock = adjustStock,
        _clock = clock ?? DateTime.now,
        super(StockState(asOf: (clock ?? DateTime.now)()));

  final GetStockBatches _getStockBatches;
  final AdjustStock _adjustStock;
  final DateTime Function() _clock;
  int _noticeSequence = 0;

  void _notify(String message) {
    emit(state.copyWith(notice: StockNotice(id: ++_noticeSequence, message: message)));
  }

  Future<void> load() async {
    emit(StockState(
      asOf: state.asOf,
      status: StockStatus.loading,
      batches: state.batches,
      query: state.query,
      filter: state.filter,
      view: state.view,
      notice: state.notice,
    ));
    final result = await _getStockBatches();
    switch (result) {
      case Ok<List<StockBatch>>(:final value):
        emit(StockState(
          asOf: _clock(),
          status: StockStatus.loaded,
          batches: value,
          query: state.query,
          filter: state.filter,
          view: state.view,
          notice: state.notice,
        ));
      case Err<List<StockBatch>>(:final failure):
        emit(StockState(
          asOf: state.asOf,
          status: StockStatus.failure,
          batches: state.batches,
          query: state.query,
          filter: state.filter,
          view: state.view,
          failure: failure,
          notice: state.notice,
        ));
    }
  }

  void setQuery(String query) => emit(state.copyWith(query: query));
  void setFilter(StockFilter filter) => emit(state.copyWith(filter: filter));
  void setView(StockView view) => emit(state.copyWith(view: view));

  /// Returns null on success, or the message to show in the dialog.
  Future<String?> adjust(StockAdjustmentDraft draft) async {
    final result = await _adjustStock(draft);
    switch (result) {
      case Ok<StockBatch>(:final value):
        emit(state.copyWith(
          batches: [for (final b in state.batches) b.id == value.id ? value : b],
        ));
        _notify(StockStrings.adjusted(value.medicineName, value.batchNumber));
        return null;
      case Err<StockBatch>(:final failure):
        return failure.message;
    }
  }
}
