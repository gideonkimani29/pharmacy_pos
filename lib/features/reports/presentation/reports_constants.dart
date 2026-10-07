import '../domain/entities/losses_report.dart';
import '../domain/entities/sales_report.dart';

abstract final class ReportsStrings {
  static const String title = 'Reports';
  static const String subtitle = 'Sales, profit and losses for any period';
  static const String copyCsv = 'Copy as CSV';
  static String csvCopied(String report) => '$report copied. Paste it into Excel or Google Sheets.';
  static const String nothingToCopy = 'Nothing to copy yet.';

  static const String presetToday = 'Today';
  static const String presetLast7 = 'Last 7 days';
  static const String presetLast30 = 'Last 30 days';
  static const String presetThisMonth = 'This month';
  static const String presetCustom = 'Custom range';
  static String rangeLabel(String from, String to) => from == to ? from : '$from to $to';
  static const String pickRangeHelp = 'Choose the period';

  static const String tabSales = 'Sales';
  static const String tabProfit = 'Profit';
  static const String tabLosses = 'Losses';

  // Sales
  static const String kpiNetSales = 'Net sales';
  static String kpiDiscounts(String amount) => 'Discounts given $amount';
  static const String kpiTransactions = 'Sales made';
  static const String kpiItemsSold = 'Items sold';
  static const String kpiAverageSale = 'Average sale';
  static const String byPayment = 'By payment method';
  static const String payCash = 'Cash';
  static const String payMobile = 'Mobile (M-Pesa)';
  static const String payCard = 'Card';
  static const String payCredit = 'On credit';
  static const String dailySales = 'Sales by day';
  static const String colDate = 'Date';
  static const String colSales = 'Sales';
  static const String colItems = 'Items';
  static const String colGross = 'Gross';
  static const String colDiscount = 'Discount';
  static const String colNet = 'Net';
  static const String totalRow = 'Total';

  // Profit
  static const String kpiRevenue = 'Revenue';
  static const String kpiCost = 'Cost of goods';
  static const String kpiProfit = 'Gross profit';
  static const String kpiMargin = 'Margin';
  static const String productProfit = 'Profit by product';
  static const String colProduct = 'Product';
  static const String colUnits = 'Units';
  static const String colRevenue = 'Revenue';
  static const String colCost = 'Cost';
  static const String colProfit = 'Profit';
  static const String colMargin = 'Margin';
  static const String profitNote =
      'Cost is the buying price of the batches actually sold (first-expired, first-out), so it follows your purchases.';

  // Losses
  static const String kpiTotalLoss = 'Total loss (at cost)';
  static const String kpiExpired = 'Expired stock';
  static const String kpiDamaged = 'Damaged or lost';
  static const String kpiShortage = 'Count shortages';
  static const String lossesTitle = 'Write-offs and shortages';
  static const String colMedicine = 'Medicine';
  static const String colBatch = 'Batch';
  static const String colQuantity = 'Qty';
  static const String colUnitCost = 'Unit cost';
  static const String colLoss = 'Loss';
  static const String colReason = 'Reason';
  static const String noLosses = 'No write-offs or shortages in this period.';

  static const String loadFailed = 'Could not load reports';
  static const String retry = 'Try again';

  static String paymentLabel(ReportPayment method) => switch (method) {
        ReportPayment.cash => payCash,
        ReportPayment.mobile => payMobile,
        ReportPayment.card => payCard,
        ReportPayment.credit => payCredit,
      };

  static String lossReasonLabel(LossReason reason) => switch (reason) {
        LossReason.expired => 'Expired',
        LossReason.damaged => 'Damaged or lost',
        LossReason.countShortage => 'Count shortage',
      };
}

abstract final class ReportsLayout {
  static const double kpiWidth = 270;
  static const double paymentLabelWidth = 150;
  static const double paymentShareWidth = 70;
  static const double paymentAmountWidth = 150;
  static const double paymentBarHeight = 8;
  static const double tableMinWidth = 760;
  static const int dateFlex = 3;
  static const int numberFlex = 2;
  static const int moneyFlex = 3;
  static const int nameFlex = 6;
}
