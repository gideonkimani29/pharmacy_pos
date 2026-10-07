import '../../../../core/result/result.dart';
import '../../domain/entities/losses_report.dart';
import '../../domain/entities/profit_report.dart';
import '../../domain/entities/report_range.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/repositories/report_repository.dart';

/// Deterministic sample numbers (the same date always gives the same figures)
/// so the module can be built before the Go API exists. Replace with a
/// REST-backed repository. The profit report is built from the same sales
/// total, so the three reports agree with each other.
class DemoReportRepository implements ReportRepository {
  DemoReportRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const Duration _latency = Duration(milliseconds: 300);
  static const int _percentDenominator = 100;
  static const int _basisPointDenominator = 10000;

  final DateTime Function() _clock;

  @override
  Future<Result<SalesReport>> sales(ReportRange range) async {
    await Future<void>.delayed(_latency);
    return Ok(_buildSales(range));
  }

  @override
  Future<Result<ProfitReport>> profit(ReportRange range) async {
    await Future<void>.delayed(_latency);
    final revenue = _buildSales(range).netMinor;

    // Share of revenue per product; the first product takes the rounding remainder.
    final shares = _productLines.map((l) => revenue * l.sharePercent ~/ _percentDenominator).toList();
    shares[0] += revenue - shares.fold(0, (sum, s) => sum + s);

    return Ok(ProfitReport(
      range: range,
      products: [
        for (var i = 0; i < _productLines.length; i++)
          ProductProfit(
            name: _productLines[i].name,
            unitsSold: shares[i] ~/ _productLines[i].unitPriceMinor,
            revenueMinor: shares[i],
            costMinor: shares[i] * _productLines[i].costBasisPoints ~/ _basisPointDenominator,
          ),
      ],
    ));
  }

  @override
  Future<Result<LossesReport>> losses(ReportRange range) async {
    await Future<void>.delayed(_latency);
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);

    final rows = <LossRow>[];
    for (final event in _lossEvents) {
      final date = DateTime(today.year, today.month, today.day - event.daysAgo);
      if (!range.contains(date)) continue;
      rows.add(LossRow(
        date: date,
        medicineName: event.medicine,
        batchNumber: event.batch,
        quantity: event.quantity,
        unitCostMinor: event.unitCostMinor,
        reason: event.reason,
      ));
    }
    rows.sort((a, b) => b.date.compareTo(a.date));
    return Ok(LossesReport(range: range, rows: rows));
  }

  // ---- sales ---------------------------------------------------------------

  static final DateTime _epoch = DateTime.utc(2026, 1, 1);
  static const int _cashPercent = 55;
  static const int _mobilePercent = 30;
  static const int _cardPercent = 8;

  SalesReport _buildSales(ReportRange range) {
    final days = <DailySalesRow>[];
    var cash = 0;
    var mobile = 0;
    var card = 0;
    var credit = 0;

    for (var i = 0; i < range.dayCount; i++) {
      final date = range.dayAt(i);
      final day = _day(date);
      days.add(day);

      final net = day.netMinor;
      final dayCash = net * _cashPercent ~/ _percentDenominator;
      final dayMobile = net * _mobilePercent ~/ _percentDenominator;
      final dayCard = net * _cardPercent ~/ _percentDenominator;
      cash += dayCash;
      mobile += dayMobile;
      card += dayCard;
      credit += net - dayCash - dayMobile - dayCard;
    }

    return SalesReport(
      range: range,
      days: days,
      byPayment: [
        PaymentTotal(method: ReportPayment.cash, amountMinor: cash),
        PaymentTotal(method: ReportPayment.mobile, amountMinor: mobile),
        PaymentTotal(method: ReportPayment.card, amountMinor: card),
        PaymentTotal(method: ReportPayment.credit, amountMinor: credit),
      ],
    );
  }

  DailySalesRow _day(DateTime date) {
    final seed = DateTime.utc(date.year, date.month, date.day).difference(_epoch).inDays;
    var transactions = 20 + seed % 15;
    if (date.weekday == DateTime.sunday) transactions = transactions * 6 ~/ 10;

    final averageBasket = 70000 + (seed * 13 % 40) * 1000;
    final gross = transactions * averageBasket;
    final discount = gross * (seed % 4) ~/ _percentDenominator;

    return DailySalesRow(
      date: date,
      transactions: transactions,
      itemsSold: transactions * 3 + seed % 10,
      grossMinor: gross,
      discountMinor: discount,
    );
  }

  // ---- profit --------------------------------------------------------------

  static const List<_ProductLine> _productLines = [
    _ProductLine('Panadol 500mg x24', 22, 18000, 6700),
    _ProductLine('Vitamin C 1000mg x20', 16, 36000, 6800),
    _ProductLine('Brufen 400mg x30', 12, 32000, 6600),
    _ProductLine('Amoxil 500mg capsules x21', 10, 45000, 6700),
    _ProductLine('Zinc 20mg dispersible x10', 9, 15000, 6300),
    _ProductLine('Zyrtec 10mg x10', 8, 28000, 6100),
    _ProductLine('Glucophage 500mg x60', 7, 62000, 6600),
    _ProductLine('Voltaren Emulgel 50g', 6, 89000, 6740),
    _ProductLine('ORS sachet', 5, 3500, 5700),
    _ProductLine('Imodium 2mg x12', 5, 41000, 6600),
  ];

  // ---- losses --------------------------------------------------------------

  static const List<_LossEvent> _lossEvents = [
    _LossEvent(3, 'Aspirin 75mg x28', 'AS2308', 14, 8000, LossReason.expired),
    _LossEvent(10, 'Coartem 80/480mg x6', 'CO2410', 2, 36000, LossReason.damaged),
    _LossEvent(15, 'Zyrtec 10mg x10', 'ZY2312', 60, 16500, LossReason.expired),
    _LossEvent(20, 'ORS sachet', 'OR2501', 5, 2000, LossReason.countShortage),
    _LossEvent(40, 'Amoxil 500mg capsules x21', 'AX2403', 8, 30000, LossReason.damaged),
    _LossEvent(75, 'Betadine solution 100ml', 'BE2402', 12, 21000, LossReason.expired),
  ];
}

class _ProductLine {
  const _ProductLine(this.name, this.sharePercent, this.unitPriceMinor, this.costBasisPoints);

  final String name;
  final int sharePercent;
  final int unitPriceMinor;
  final int costBasisPoints;
}

class _LossEvent {
  const _LossEvent(this.daysAgo, this.medicine, this.batch, this.quantity, this.unitCostMinor, this.reason);

  final int daysAgo;
  final String medicine;
  final String batch;
  final int quantity;
  final int unitCostMinor;
  final LossReason reason;
}
