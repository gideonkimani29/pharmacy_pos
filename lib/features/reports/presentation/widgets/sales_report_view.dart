import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../../domain/entities/sales_report.dart';
import '../report_format.dart';
import '../reports_constants.dart';
import 'report_shared.dart';

class SalesReportView extends StatelessWidget {
  const SalesReportView({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportKpiRow(
          cards: [
            KpiCard(
              icon: Icons.payments_outlined,
              label: ReportsStrings.kpiNetSales,
              value: Money.format(report.netMinor),
              caption: ReportsStrings.kpiDiscounts(Money.format(report.discountMinor)),
              foreground: AppColors.successFg,
              background: AppColors.successBg,
            ),
            KpiCard(
              icon: Icons.receipt_long_outlined,
              label: ReportsStrings.kpiTransactions,
              value: '${report.transactions}',
              foreground: AppColors.infoFg,
              background: AppColors.infoBg,
            ),
            KpiCard(
              icon: Icons.medication_outlined,
              label: ReportsStrings.kpiItemsSold,
              value: '${report.itemsSold}',
              foreground: AppColors.rxFg,
              background: AppColors.rxBg,
            ),
            KpiCard(
              icon: Icons.shopping_basket_outlined,
              label: ReportsStrings.kpiAverageSale,
              value: Money.format(report.averageSaleMinor),
              foreground: AppColors.warningFg,
              background: AppColors.warningBg,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ReportCard(
          title: ReportsStrings.byPayment,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.spaceLg, 0, AppDimens.spaceLg, AppDimens.spaceLg),
            child: Column(
              children: [for (final payment in report.byPayment) _PaymentRow(payment: payment, net: report.netMinor)],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ReportCard(
          title: ReportsStrings.dailySales,
          child: ReportTable(
            columns: const [
              ReportColumn(ReportsStrings.colDate, flex: ReportsLayout.dateFlex),
              ReportColumn(ReportsStrings.colSales, flex: ReportsLayout.numberFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colItems, flex: ReportsLayout.numberFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colGross, flex: ReportsLayout.moneyFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colDiscount, flex: ReportsLayout.moneyFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colNet, flex: ReportsLayout.moneyFlex, alignEnd: true),
            ],
            rows: [
              for (final day in report.days.reversed)
                [
                  ReportText(AppDates.short(day.date)),
                  ReportText('${day.transactions}'),
                  ReportText('${day.itemsSold}'),
                  ReportText(Money.format(day.grossMinor)),
                  ReportText(Money.format(day.discountMinor)),
                  ReportText(Money.format(day.netMinor), bold: true),
                ],
            ],
            footer: [
              const ReportText(ReportsStrings.totalRow, bold: true),
              ReportText('${report.transactions}', bold: true),
              ReportText('${report.itemsSold}', bold: true),
              ReportText(Money.format(report.grossMinor), bold: true),
              ReportText(Money.format(report.discountMinor), bold: true),
              ReportText(Money.format(report.netMinor), bold: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.net});

  final PaymentTotal payment;
  final int net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Display only: the share drives the bar length, never a money figure.
    final share = net <= 0 ? 0.0 : (payment.amountMinor / net).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Row(
        children: [
          SizedBox(
            width: ReportsLayout.paymentLabelWidth,
            child: Text(ReportsStrings.paymentLabel(payment.method), style: theme.textTheme.bodyLarge),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ReportsLayout.paymentBarHeight),
              child: LinearProgressIndicator(
                value: share,
                minHeight: ReportsLayout.paymentBarHeight,
                backgroundColor: AppColors.neutralBg,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(
            width: ReportsLayout.paymentShareWidth,
            child: Text(
              ReportFormat.percent(payment.amountMinor, net),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: ReportsLayout.paymentAmountWidth,
            child: Text(
              Money.format(payment.amountMinor),
              textAlign: TextAlign.right,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
