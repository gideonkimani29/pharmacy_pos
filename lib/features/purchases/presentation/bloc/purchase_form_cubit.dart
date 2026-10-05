import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../../../checkout/domain/entities/product.dart';
import '../../../checkout/domain/usecases/search_products.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/usecases/get_suppliers.dart';
import '../../domain/usecases/record_purchase.dart';
import '../purchases_constants.dart';

enum PurchaseFormStatus { editing, submitting, saved }

/// A line being typed. Amounts are minor units; 0 means "not entered yet".
class DraftLine extends Equatable {
  const DraftLine({
    required this.id,
    required this.product,
    required this.sellingPriceMinor,
    this.batchNumber = '',
    this.expiryDate,
    this.quantity = 1,
    this.unitCostMinor = 0,
  });

  final int id;
  final Product product;
  final String batchNumber;
  final DateTime? expiryDate;
  final int quantity;
  final int unitCostMinor;
  final int sellingPriceMinor;

  int get lineTotalMinor => unitCostMinor * quantity;
  bool get sellsBelowCost => unitCostMinor > 0 && sellingPriceMinor > 0 && sellingPriceMinor < unitCostMinor;

  DraftLine copyWith({
    String? batchNumber,
    DateTime? expiryDate,
    int? quantity,
    int? unitCostMinor,
    int? sellingPriceMinor,
  }) {
    return DraftLine(
      id: id,
      product: product,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      unitCostMinor: unitCostMinor ?? this.unitCostMinor,
      sellingPriceMinor: sellingPriceMinor ?? this.sellingPriceMinor,
    );
  }

  @override
  List<Object?> get props => [id, product, batchNumber, expiryDate, quantity, unitCostMinor, sellingPriceMinor];
}

class PurchaseNotice extends Equatable {
  const PurchaseNotice({required this.id, required this.message});

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

class PurchaseFormState extends Equatable {
  const PurchaseFormState({
    required this.receivedOn,
    required this.idempotencyKey,
    this.suppliers = const [],
    this.supplier,
    this.invoiceNumber = '',
    this.paymentStatus = PurchasePaymentStatus.paid,
    this.lines = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.searching = false,
    this.status = PurchaseFormStatus.editing,
    this.savedPurchase,
    this.notice,
  });

  final DateTime receivedOn;
  final String idempotencyKey;
  final List<Supplier> suppliers;
  final Supplier? supplier;
  final String invoiceNumber;
  final PurchasePaymentStatus paymentStatus;
  final List<DraftLine> lines;
  final String searchQuery;
  final List<Product> searchResults;
  final bool searching;
  final PurchaseFormStatus status;
  final Purchase? savedPurchase;
  final PurchaseNotice? notice;

  bool get isSubmitting => status == PurchaseFormStatus.submitting;
  int get totalMinor => lines.fold(0, (sum, line) => sum + line.lineTotalMinor);
  int get unitCount => lines.fold(0, (sum, line) => sum + line.quantity);

  PurchaseFormState copyWith({
    DateTime? receivedOn,
    String? idempotencyKey,
    List<Supplier>? suppliers,
    Supplier? supplier,
    String? invoiceNumber,
    PurchasePaymentStatus? paymentStatus,
    List<DraftLine>? lines,
    String? searchQuery,
    List<Product>? searchResults,
    bool? searching,
    PurchaseFormStatus? status,
    Purchase? savedPurchase,
    PurchaseNotice? notice,
  }) {
    return PurchaseFormState(
      receivedOn: receivedOn ?? this.receivedOn,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      suppliers: suppliers ?? this.suppliers,
      supplier: supplier ?? this.supplier,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      lines: lines ?? this.lines,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      searching: searching ?? this.searching,
      status: status ?? this.status,
      savedPurchase: savedPurchase ?? this.savedPurchase,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
        receivedOn,
        idempotencyKey,
        suppliers,
        supplier,
        invoiceNumber,
        paymentStatus,
        lines,
        searchQuery,
        searchResults,
        searching,
        status,
        savedPurchase,
        notice,
      ];
}

class PurchaseFormCubit extends Cubit<PurchaseFormState> {
  PurchaseFormCubit({
    required GetSuppliers getSuppliers,
    required SearchProducts searchProducts,
    required RecordPurchase recordPurchase,
    DateTime Function()? clock,
  })  : _getSuppliers = getSuppliers,
        _searchProducts = searchProducts,
        _recordPurchase = recordPurchase,
        super(PurchaseFormState(
          receivedOn: _today((clock ?? DateTime.now)()),
          idempotencyKey: IdempotencyKey.generate(),
        ));

  final GetSuppliers _getSuppliers;
  final SearchProducts _searchProducts;
  final RecordPurchase _recordPurchase;
  Timer? _debounce;
  int _lineSequence = 0;
  int _noticeSequence = 0;

  static DateTime _today(DateTime now) => DateTime(now.year, now.month, now.day);

  void _notify(String message) {
    emit(state.copyWith(notice: PurchaseNotice(id: ++_noticeSequence, message: message)));
  }

  /// Any change to what will be posted gets a fresh idempotency key.
  String _freshKey() => IdempotencyKey.generate();

  Future<void> load() async {
    final result = await _getSuppliers();
    if (isClosed) return;
    switch (result) {
      case Ok<List<Supplier>>(:final value):
        emit(state.copyWith(suppliers: value));
      case Err<List<Supplier>>():
        _notify(PurchasesStrings.suppliersLoadFailed);
    }
  }

  void setSupplier(Supplier supplier) =>
      emit(state.copyWith(supplier: supplier, idempotencyKey: _freshKey()));

  void setInvoiceNumber(String value) =>
      emit(state.copyWith(invoiceNumber: value, idempotencyKey: _freshKey()));

  void setReceivedOn(DateTime date) => emit(state.copyWith(receivedOn: date, idempotencyKey: _freshKey()));

  void setPaymentStatus(PurchasePaymentStatus status) =>
      emit(state.copyWith(paymentStatus: status, idempotencyKey: _freshKey()));

  void search(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(searchQuery: '', searchResults: const [], searching: false));
      return;
    }
    emit(state.copyWith(searchQuery: trimmed, searching: true));
    _debounce = Timer(AppConfig.searchDebounce, () async {
      final result = await _searchProducts(trimmed);
      if (isClosed || state.searchQuery != trimmed) return;
      switch (result) {
        case Ok<List<Product>>(:final value):
          emit(state.copyWith(searchResults: value, searching: false));
        case Err<List<Product>>(:final failure):
          emit(state.copyWith(searching: false));
          _notify(failure.message);
      }
    });
  }

  /// The same product can be added more than once (one line per batch).
  void addProduct(Product product) {
    final line = DraftLine(
      id: ++_lineSequence,
      product: product,
      sellingPriceMinor: product.unitPriceMinor,
    );
    emit(state.copyWith(
      lines: [...state.lines, line],
      searchQuery: '',
      searchResults: const [],
      searching: false,
      idempotencyKey: _freshKey(),
    ));
  }

  void updateLine(int id, DraftLine Function(DraftLine line) change) {
    emit(state.copyWith(
      lines: [for (final line in state.lines) line.id == id ? change(line) : line],
      idempotencyKey: _freshKey(),
    ));
  }

  void removeLine(int id) {
    emit(state.copyWith(
      lines: state.lines.where((line) => line.id != id).toList(),
      idempotencyKey: _freshKey(),
    ));
  }

  Future<void> submit() async {
    if (state.isSubmitting) return;

    final request = PurchaseRequest(
      idempotencyKey: state.idempotencyKey,
      supplierId: state.supplier?.id,
      invoiceNumber: state.invoiceNumber,
      receivedOn: state.receivedOn,
      paymentStatus: state.paymentStatus,
      lines: [
        for (final line in state.lines)
          PurchaseLine(
            productId: line.product.id,
            productName: line.product.name,
            batchNumber: line.batchNumber,
            expiryDate: line.expiryDate,
            quantity: line.quantity,
            unitCostMinor: line.unitCostMinor,
            sellingPriceMinor: line.sellingPriceMinor,
          ),
      ],
    );

    emit(state.copyWith(status: PurchaseFormStatus.submitting));
    final result = await _recordPurchase(request);
    if (isClosed) return;
    switch (result) {
      case Ok<Purchase>(:final value):
        emit(state.copyWith(status: PurchaseFormStatus.saved, savedPurchase: value));
      case Err<Purchase>(:final failure):
        emit(state.copyWith(status: PurchaseFormStatus.editing));
        _notify(failure.message);
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
