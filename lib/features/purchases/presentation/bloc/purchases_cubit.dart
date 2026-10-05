import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/usecases/get_purchases.dart';

enum PurchasesStatus { loading, loaded, failure }

class PurchasesState extends Equatable {
  const PurchasesState({this.status = PurchasesStatus.loading, this.purchases = const [], this.failure});

  final PurchasesStatus status;
  final List<Purchase> purchases;
  final Failure? failure;

  int get owedToSuppliersMinor => purchases
      .where((p) => p.paymentStatus == PurchasePaymentStatus.onCredit)
      .fold(0, (sum, p) => sum + p.totalMinor);

  @override
  List<Object?> get props => [status, purchases, failure];
}

class PurchasesCubit extends Cubit<PurchasesState> {
  PurchasesCubit({required GetPurchases getPurchases})
      : _getPurchases = getPurchases,
        super(const PurchasesState());

  final GetPurchases _getPurchases;

  Future<void> load() async {
    emit(PurchasesState(status: PurchasesStatus.loading, purchases: state.purchases));
    final result = await _getPurchases();
    switch (result) {
      case Ok<List<Purchase>>(:final value):
        emit(PurchasesState(status: PurchasesStatus.loaded, purchases: value));
      case Err<List<Purchase>>(:final failure):
        emit(PurchasesState(status: PurchasesStatus.failure, purchases: state.purchases, failure: failure));
    }
  }
}
