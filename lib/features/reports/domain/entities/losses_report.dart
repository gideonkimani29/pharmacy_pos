import 'package:equatable/equatable.dart';

import 'report_range.dart';

enum LossReason { expired, damaged, countShortage }

class LossRow extends Equatable {
  const LossRow({
    required this.date,
    required this.medicineName,
    required this.batchNumber,
    required this.quantity,
    required this.unitCostMinor,
    required this.reason,
  });

  final DateTime date;
  final String medicineName;
  final String batchNumber;
  final int quantity;
  final int unitCostMinor;
  final LossReason reason;

  int get lossMinor => quantity * unitCostMinor;

  @override
  List<Object?> get props => [date, medicineName, batchNumber, quantity, unitCostMinor, reason];
}

class LossesReport extends Equatable {
  const LossesReport({required this.range, required this.rows});

  final ReportRange range;
  final List<LossRow> rows;

  int get totalLossMinor => rows.fold(0, (sum, r) => sum + r.lossMinor);

  int lossFor(LossReason reason) =>
      rows.where((r) => r.reason == reason).fold(0, (sum, r) => sum + r.lossMinor);

  @override
  List<Object?> get props => [range, rows];
}
