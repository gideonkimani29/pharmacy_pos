import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, card, mobile }

extension PaymentMethodX on PaymentMethod {
  bool get isCash => this == PaymentMethod.cash;
  bool get needsReference => !isCash;
}

class PaymentLine extends Equatable {
  const PaymentLine({required this.method, required this.amountMinor, this.reference});

  final PaymentMethod method;

  /// Amount tendered. For cash this may exceed what is owed (change is given).
  final int amountMinor;

  /// Card approval code or M-Pesa transaction code. Null for cash.
  final String? reference;

  @override
  List<Object?> get props => [method, amountMinor, reference];
}
