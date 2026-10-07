import 'package:equatable/equatable.dart';

import 'report_range.dart';

enum ReportPayment { cash, mobile, card, credit }

class DailySalesRow extends Equatable {
  const DailySalesRow({
    required this.date,
    required this.transactions,
    required this.itemsSold,
    required this.grossMinor,
    required this.discountMinor,
  });

  final DateTime date;
  final int transactions;
  final int itemsSold;
  final int grossMinor;
  final int discountMinor;

  int get netMinor => grossMinor - discountMinor;

  @override
  List<Object?> get props => [date, transactions, itemsSold, grossMinor, discountMinor];
}

class PaymentTotal extends Equatable {
  const PaymentTotal({required this.method, required this.amountMinor});

  final ReportPayment method;
  final int amountMinor;

  @override
  List<Object?> get props => [method, amountMinor];
}

class SalesReport extends Equatable {
  const SalesReport({required this.range, required this.days, required this.byPayment});

  final ReportRange range;
  final List<DailySalesRow> days;
  final List<PaymentTotal> byPayment;

  int get grossMinor => days.fold(0, (sum, d) => sum + d.grossMinor);
  int get discountMinor => days.fold(0, (sum, d) => sum + d.discountMinor);
  int get netMinor => grossMinor - discountMinor;
  int get transactions => days.fold(0, (sum, d) => sum + d.transactions);
  int get itemsSold => days.fold(0, (sum, d) => sum + d.itemsSold);
  int get averageSaleMinor => transactions == 0 ? 0 : netMinor ~/ transactions;

  @override
  List<Object?> get props => [range, days, byPayment];
}
