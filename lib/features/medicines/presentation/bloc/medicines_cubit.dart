import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/medicine.dart';
import '../../domain/usecases/get_medicines.dart';
import '../../domain/usecases/save_medicine.dart';
import '../../domain/usecases/set_medicine_active.dart';
import '../medicines_constants.dart';

enum MedicinesStatus { loading, loaded, failure }

enum MedicineFilter { all, lowStock, outOfStock, prescription, inactive }

class MedicinesNotice extends Equatable {
  const MedicinesNotice({required this.id, required this.message});

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

class MedicinesState extends Equatable {
  const MedicinesState({
    this.status = MedicinesStatus.loading,
    this.medicines = const [],
    this.query = '',
    this.filter = MedicineFilter.all,
    this.failure,
    this.notice,
  });

  final MedicinesStatus status;
  final List<Medicine> medicines;
  final String query;
  final MedicineFilter filter;
  final Failure? failure;
  final MedicinesNotice? notice;

  static bool _matchesFilter(Medicine m, MedicineFilter filter) => switch (filter) {
        MedicineFilter.all => true,
        MedicineFilter.lowStock => m.isActive && m.stockLevel == StockLevel.low,
        MedicineFilter.outOfStock => m.isActive && m.stockLevel == StockLevel.out,
        MedicineFilter.prescription => m.requiresPrescription,
        MedicineFilter.inactive => !m.isActive,
      };

  int count(MedicineFilter filter) => medicines.where((m) => _matchesFilter(m, filter)).length;
  int get activeCount => medicines.where((m) => m.isActive).length;

  List<Medicine> get visible {
    final needle = query.trim().toLowerCase();
    return medicines.where((m) {
      if (!_matchesFilter(m, filter)) return false;
      if (needle.isEmpty) return true;
      return m.name.toLowerCase().contains(needle) ||
          m.genericName.toLowerCase().contains(needle) ||
          m.sku.toLowerCase().contains(needle) ||
          m.barcode.toLowerCase().contains(needle);
    }).toList();
  }

  MedicinesState copyWith({
    MedicinesStatus? status,
    List<Medicine>? medicines,
    String? query,
    MedicineFilter? filter,
    Failure? failure,
    MedicinesNotice? notice,
  }) {
    return MedicinesState(
      status: status ?? this.status,
      medicines: medicines ?? this.medicines,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      failure: failure ?? this.failure,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [status, medicines, query, filter, failure, notice];
}

class MedicinesCubit extends Cubit<MedicinesState> {
  MedicinesCubit({
    required GetMedicines getMedicines,
    required SaveMedicine saveMedicine,
    required SetMedicineActive setMedicineActive,
  })  : _getMedicines = getMedicines,
        _saveMedicine = saveMedicine,
        _setMedicineActive = setMedicineActive,
        super(const MedicinesState());

  final GetMedicines _getMedicines;
  final SaveMedicine _saveMedicine;
  final SetMedicineActive _setMedicineActive;
  int _noticeSequence = 0;

  static List<Medicine> _sorted(Iterable<Medicine> items) =>
      items.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _notify(String message) {
    emit(state.copyWith(notice: MedicinesNotice(id: ++_noticeSequence, message: message)));
  }

  Future<void> load() async {
    emit(MedicinesState(
      status: MedicinesStatus.loading,
      medicines: state.medicines,
      query: state.query,
      filter: state.filter,
      notice: state.notice,
    ));
    final result = await _getMedicines();
    switch (result) {
      case Ok<List<Medicine>>(:final value):
        emit(MedicinesState(
          status: MedicinesStatus.loaded,
          medicines: _sorted(value),
          query: state.query,
          filter: state.filter,
          notice: state.notice,
        ));
      case Err<List<Medicine>>(:final failure):
        emit(MedicinesState(
          status: MedicinesStatus.failure,
          medicines: state.medicines,
          query: state.query,
          filter: state.filter,
          failure: failure,
          notice: state.notice,
        ));
    }
  }

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setFilter(MedicineFilter filter) => emit(state.copyWith(filter: filter));

  /// Returns null on success, or the message to show in the form.
  Future<String?> save(MedicineDraft draft, {String? id}) async {
    final result = await _saveMedicine(draft, id: id);
    switch (result) {
      case Ok<Medicine>(:final value):
        final others = state.medicines.where((m) => m.id != value.id);
        emit(state.copyWith(medicines: _sorted([...others, value])));
        _notify(MedicinesStrings.saved(value.name));
        return null;
      case Err<Medicine>(:final failure):
        return failure.message;
    }
  }

  Future<void> toggleActive(Medicine medicine) async {
    final result = await _setMedicineActive(medicine.id, active: !medicine.isActive);
    switch (result) {
      case Ok<Medicine>(:final value):
        emit(state.copyWith(
          medicines: _sorted(state.medicines.map((m) => m.id == value.id ? value : m)),
        ));
        _notify(value.isActive
            ? MedicinesStrings.activated(value.name)
            : MedicinesStrings.deactivated(value.name));
      case Err<Medicine>(:final failure):
        _notify(failure.message);
    }
  }
}
