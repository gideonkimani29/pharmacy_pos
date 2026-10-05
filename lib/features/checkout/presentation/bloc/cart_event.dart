part of 'cart_bloc.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

final class CartProductAdded extends CartEvent {
  const CartProductAdded(this.product);

  final Product product;

  @override
  List<Object?> get props => [product];
}

final class CartQuantityChanged extends CartEvent {
  const CartQuantityChanged({required this.productId, required this.quantity});

  final String productId;
  final int quantity;

  @override
  List<Object?> get props => [productId, quantity];
}

final class CartItemRemoved extends CartEvent {
  const CartItemRemoved(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

final class CartCleared extends CartEvent {
  const CartCleared();
}

final class CartPrescriptionToggled extends CartEvent {
  const CartPrescriptionToggled({required this.verified});

  final bool verified;

  @override
  List<Object?> get props => [verified];
}

final class CartCheckoutSubmitted extends CartEvent {
  const CartCheckoutSubmitted(this.payments);

  final List<PaymentLine> payments;

  @override
  List<Object?> get props => [payments];
}

/// Dispatched once the cashier dismisses the "sale complete" dialog.
final class CartSaleAcknowledged extends CartEvent {
  const CartSaleAcknowledged();
}

/// Dispatched by the UI to surface a message through the same notice channel.
final class CartNoticeRaised extends CartEvent {
  const CartNoticeRaised(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class CartCustomerSelected extends CartEvent {
  const CartCustomerSelected(this.customer);

  /// Null clears the customer.
  final Customer? customer;

  @override
  List<Object?> get props => [customer];
}

final class CartSaleTypeChanged extends CartEvent {
  const CartSaleTypeChanged(this.saleType);

  final SaleType saleType;

  @override
  List<Object?> get props => [saleType];
}

final class CartDiscountChanged extends CartEvent {
  const CartDiscountChanged(this.discountMinor);

  final int discountMinor;

  @override
  List<Object?> get props => [discountMinor];
}
