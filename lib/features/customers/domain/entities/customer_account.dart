import 'package:equatable/equatable.dart';

import '../../../checkout/domain/entities/payment.dart';

/// A registered customer and their credit account.
class CustomerAccount extends Equatable {
  const CustomerAccount({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.creditLimitMinor,
    required this.balanceMinor,
    required this.isActive,
    this.lastPurchaseOn,
  });

  final String id;
  final String name;
  final String phone;

  /// Empty when not given.
  final String email;

  /// 0 means no credit is allowed.
  final int creditLimitMinor;

  /// Amount the customer currently owes.
  final int balanceMinor;
  final bool isActive;
  final DateTime? lastPurchaseOn;

  bool get owes => balanceMinor > 0;
  bool get isOverLimit => balanceMinor > creditLimitMinor;

  int get availableCreditMinor {
    final left = creditLimitMinor - balanceMinor;
    return left > 0 ? left : 0;
  }

  CustomerAccount copyWith({bool? isActive, int? balanceMinor}) {
    return CustomerAccount(
      id: id,
      name: name,
      phone: phone,
      email: email,
      creditLimitMinor: creditLimitMinor,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      isActive: isActive ?? this.isActive,
      lastPurchaseOn: lastPurchaseOn,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        creditLimitMinor,
        balanceMinor,
        isActive,
        lastPurchaseOn,
      ];
}

/// What the user edits. Balance and active state are not edited here.
class CustomerDraft extends Equatable {
  const CustomerDraft({
    required this.name,
    required this.phone,
    required this.email,
    required this.creditLimitMinor,
  });

  final String name;
  final String phone;
  final String email;
  final int creditLimitMinor;

  @override
  List<Object?> get props => [name, phone, email, creditLimitMinor];
}

/// A payment received against a customer's account balance.
class AccountPaymentDraft extends Equatable {
  const AccountPaymentDraft({
    required this.customerId,
    required this.amountMinor,
    required this.method,
    this.reference,
  });

  final String customerId;
  final int amountMinor;
  final PaymentMethod method;

  /// Card approval code or M-Pesa transaction code. Null for cash.
  final String? reference;

  @override
  List<Object?> get props => [customerId, amountMinor, method, reference];
}
