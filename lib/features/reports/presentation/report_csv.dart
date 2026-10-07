import '../../../core/utils/money.dart';
import '../domain/entities/losses_report.dart';
import '../domain/entities/profit_report.dart';
import '../domain/entities/sales_report.dart';
import 'report_format.dart';
import 'reports_constants.dart';

/// Builds CSV text for the "Copy as CSV" button. Amounts are plain decimals
/// ("1234.50") with no currency prefix or thousands separators.
abstract final class ReportCsv {
  /// Quotes a value when it contains a comma, quote or line break.
  static String cell(String value) {
    final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  static String _row(List<String> cells) => cells.map(cell).join(',');
  static String _money(int minor) => Money.formatPlain(minor);

  static String sales(SalesReport report) {
    final lines = <String>[
      _row([
        ReportsStrings.colDate,
        ReportsStrings.colSales,
        ReportsStrings.colItems,
        ReportsStrings.colGross,
        ReportsStrings.colDiscount,
        ReportsStrings.colNet,
      ]),
      for (final day in report.days)
        _row([
          ReportFormat.isoDate(day.date),
          '${day.transactions}',
          '${day.itemsSold}',
          _money(day.grossMinor),
          _money(day.discountMinor),
          _money(day.netMinor),
        ]),
      _row([
        ReportsStrings.totalRow,
        '${report.transactions}',
        '${report.itemsSold}',
        _money(report.grossMinor),
        _money(report.discountMinor),
        _money(report.netMinor),
      ]),
      '',
      _row([ReportsStrings.byPayment, ReportsStrings.colNet]),
      for (final payment in report.byPayment)
        _row([ReportsStrings.paymentLabel(payment.method), _money(payment.amountMinor)]),
    ];
    return lines.join('\n');
  }

  static String profit(ProfitReport report) {
    final lines = <String>[
      _row([
        ReportsStrings.colProduct,
        ReportsStrings.colUnits,
        ReportsStrings.colRevenue,
        ReportsStrings.colCost,
        ReportsStrings.colProfit,
        ReportsStrings.colMargin,
      ]),
      for (final product in report.byProfit)
        _row([
          product.name,
          '${product.unitsSold}',
          _money(product.revenueMinor),
          _money(product.costMinor),
          _money(product.profitMinor),
          ReportFormat.percent(product.profitMinor, product.revenueMinor),
        ]),
      _row([
        ReportsStrings.totalRow,
        '',
        _money(report.revenueMinor),
        _money(report.costMinor),
        _money(report.profitMinor),
        ReportFormat.percent(report.profitMinor, report.revenueMinor),
      ]),
    ];
    return lines.join('\n');
  }

  static String losses(LossesReport report) {
    final lines = <String>[
      _row([
        ReportsStrings.colDate,
        ReportsStrings.colMedicine,
        ReportsStrings.colBatch,
        ReportsStrings.colQuantity,
        ReportsStrings.colUnitCost,
        ReportsStrings.colLoss,
        ReportsStrings.colReason,
      ]),
      for (final row in report.rows)
        _row([
          ReportFormat.isoDate(row.date),
          row.medicineName,
          row.batchNumber,
          '${row.quantity}',
          _money(row.unitCostMinor),
          _money(row.lossMinor),
          ReportsStrings.lossReasonLabel(row.reason),
        ]),
      _row([ReportsStrings.totalRow, '', '', '', '', _money(report.totalLossMinor), '']),
    ];
    return lines.join('\n');
  }
}
