import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/order_totals.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_type.dart';
import '../../domain/usecases/submit_sale.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({required SubmitSale submitSale, DateTime Function()? clock})
      : _submitSale = submitSale,
        _clock = clock ?? DateTime.now,
        super(CartState.initial(_newKey())) {
    on<CartProductAdded>(_onProductAdded);
    on<CartQuantityChanged>(_onQuantityChanged);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartCleared>(_onCleared);
    on<CartPrescriptionToggled>(_onPrescriptionToggled);
    on<CartCustomerSelected>(_onCustomerSelected);
    on<CartSaleTypeChanged>(_onSaleTypeChanged);
    on<CartDiscountChanged>(_onDiscountChanged);
    on<CartCheckoutSubmitted>(_onCheckoutSubmitted);
    on<CartSaleAcknowledged>(_onSaleAcknowledged);
    on<CartNoticeRaised>((event, emit) => _notify(emit, event.message));
  }

  /// 2^32 written as a literal. `1 << 32` evaluates to 0 when compiled to JavaScript (web).
  static const int _keyRandomRange = 0x100000000;
  static final Random _random = Random.secure();

  final SubmitSale _submitSale;
  final DateTime Function() _clock;
  int _noticeSequence = 0;

  static String _newKey() => '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(_keyRandomRange)}';

  void _notify(Emitter<CartState> emit, String message) {
    emit(state.copyWith(notice: CartNotice(id: ++_noticeSequence, message: message)));
  }

  int _maxQuantity(Product product) => min(product.sellableStock, AppConfig.maxLineQuantity);

  /// Any change to what will be posted gets a fresh idempotency key, so a
  /// stale key is never reused with a different payload.
  void _emitItems(Emitter<CartState> emit, List<CartItem> items, {bool resetPrescription = false}) {
    final stillNeedsCheck = items.any((item) => item.product.requiresPrescription);
    emit(state.copyWith(
      items: items,
      prescriptionVerified: stillNeedsCheck && !resetPrescription && state.prescriptionVerified,
      idempotencyKey: _newKey(),
    ));
  }

  void _onProductAdded(CartProductAdded event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    final product = event.product;
    if (!product.isSellable(_clock())) {
      _notify(emit, AppStrings.noticeOutOfStock);
      return;
    }

    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == product.id);
    final cap = _maxQuantity(product);

    if (index >= 0) {
      final current = items[index];
      if (current.quantity >= cap) {
        _notify(emit, AppStrings.noticeMaxQuantity(cap));
        return;
      }
      items[index] = current.copyWith(quantity: current.quantity + 1);
      _emitItems(emit, items);
    } else {
      items.add(CartItem(product: product, quantity: 1));
      _emitItems(emit, items, resetPrescription: product.requiresPrescription);
    }
  }

  void _onQuantityChanged(CartQuantityChanged event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == event.productId);
    if (index < 0) return;

    if (event.quantity <= 0) {
      items.removeAt(index);
      _emitItems(emit, items);
      return;
    }

    final cap = _maxQuantity(items[index].product);
    if (event.quantity > cap) {
      _notify(emit, AppStrings.noticeMaxQuantity(cap));
      return;
    }
    items[index] = items[index].copyWith(quantity: event.quantity);
    _emitItems(emit, items);
  }

  void _onItemRemoved(CartItemRemoved event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    _emitItems(emit, state.items.where((item) => item.product.id != event.productId).toList());
  }

  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    emit(CartState.initial(_newKey()));
  }

  void _onPrescriptionToggled(CartPrescriptionToggled event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    emit(state.copyWith(prescriptionVerified: event.verified));
  }

  void _onCustomerSelected(CartCustomerSelected event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    emit(state.copyWith(
      customer: event.customer,
      clearCustomer: event.customer == null,
      idempotencyKey: _newKey(),
    ));
  }

  void _onSaleTypeChanged(CartSaleTypeChanged event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    emit(state.copyWith(saleType: event.saleType, idempotencyKey: _newKey()));
  }

  void _onDiscountChanged(CartDiscountChanged event, Emitter<CartState> emit) {
    if (state.isSubmitting) return;
    if (event.discountMinor < 0 || event.discountMinor > state.subtotalMinor) {
      _notify(emit, AppStrings.errorInvalidDiscount);
      return;
    }
    emit(state.copyWith(discountMinor: event.discountMinor, idempotencyKey: _newKey()));
  }

  Future<void> _onCheckoutSubmitted(CartCheckoutSubmitted event, Emitter<CartState> emit) async {
    if (!state.canCheckout) return;
    emit(state.copyWith(status: CartStatus.submitting));

    final request = SaleRequest(
      idempotencyKey: state.idempotencyKey,
      saleType: state.saleType,
      customerId: state.customer?.id,
      lines: [
        for (final item in state.items)
          SaleLine(
            productId: item.product.id,
            productName: item.product.name,
            quantity: item.quantity,
            unitPriceMinor: item.product.unitPriceMinor,
            requiresPrescription: item.product.requiresPrescription,
          ),
      ],
      payments: event.payments,
      prescriptionVerified: state.prescriptionVerified,
      discountMinor: state.discountMinor,
      expectedTotalMinor: state.totals.totalMinor,
    );

    final result = await _submitSale(request);
    switch (result) {
      case Ok<SaleReceipt>(:final value):
        emit(state.copyWith(status: CartStatus.completed, receipt: value));
      case Err<SaleReceipt>(:final failure):
        emit(state.copyWith(status: CartStatus.editing));
        _notify(emit, failure.message);
    }
  }

  void _onSaleAcknowledged(CartSaleAcknowledged event, Emitter<CartState> emit) {
    emit(CartState.initial(_newKey()));
  }
}
