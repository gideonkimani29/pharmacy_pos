part of 'cart_bloc.dart';

enum CartStatus { editing, submitting, completed }

/// One-shot message for the UI. [id] makes identical messages distinct.
class CartNotice extends Equatable {
  const CartNotice({required this.id, required this.message});

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

class CartState extends Equatable {
  const CartState({
    required this.items,
    required this.status,
    required this.prescriptionVerified,
    required this.idempotencyKey,
    required this.saleType,
    required this.discountMinor,
    this.customer,
    this.receipt,
    this.notice,
  });

  factory CartState.initial(String idempotencyKey) => CartState(
        items: const [],
        status: CartStatus.editing,
        prescriptionVerified: false,
        idempotencyKey: idempotencyKey,
        saleType: SaleType.cash,
        discountMinor: 0,
      );

  final List<CartItem> items;
  final CartStatus status;
  final bool prescriptionVerified;
  final String idempotencyKey;
  final SaleType saleType;
  final int discountMinor;
  final Customer? customer;
  final SaleReceipt? receipt;
  final CartNotice? notice;

  bool get isEmpty => items.isEmpty;
  bool get isSubmitting => status == CartStatus.submitting;
  int get unitCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get subtotalMinor => items.fold(0, (sum, item) => sum + item.lineTotalMinor);
  OrderTotals get totals => OrderTotals.fromSubtotal(subtotalMinor, discountMinor: discountMinor);
  bool get requiresPrescriptionCheck => items.any((item) => item.product.requiresPrescription);

  bool get canCheckout =>
      items.isNotEmpty &&
      status == CartStatus.editing &&
      (!requiresPrescriptionCheck || prescriptionVerified) &&
      (saleType == SaleType.cash || customer != null);

  CartState copyWith({
    List<CartItem>? items,
    CartStatus? status,
    bool? prescriptionVerified,
    String? idempotencyKey,
    SaleType? saleType,
    int? discountMinor,
    Customer? customer,
    bool clearCustomer = false,
    SaleReceipt? receipt,
    CartNotice? notice,
  }) {
    return CartState(
      items: items ?? this.items,
      status: status ?? this.status,
      prescriptionVerified: prescriptionVerified ?? this.prescriptionVerified,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      saleType: saleType ?? this.saleType,
      discountMinor: discountMinor ?? this.discountMinor,
      customer: clearCustomer ? null : (customer ?? this.customer),
      receipt: receipt ?? this.receipt,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
        items,
        status,
        prescriptionVerified,
        idempotencyKey,
        saleType,
        discountMinor,
        customer,
        receipt,
        notice,
      ];
}
