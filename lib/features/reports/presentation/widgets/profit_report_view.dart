import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../../domain/entities/profit_report.dart';
import '../report_format.dart';
import '../reports_constants.dart';
import 'report_shared.dart';

class ProfitReportView extends StatelessWidget {
  const ProfitReportView({super.key, required this.report});

  final ProfitReport report;

  @override
  Widget build(BuildContext context) {
    final profitColor = report.profitMinor < 0 ? AppColors.dangerFg : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportKpiRow(
          cards: [
            KpiCard(
              icon: Icons.payments_outlined,
              label: ReportsStrings.kpiRevenue,
              value: Money.format(report.revenueMinor),
              foreground: AppColors.infoFg,
              background: AppColors.infoBg,
            ),
            KpiCard(
              icon: Icons.inventory_2_outlined,
              label: ReportsStrings.kpiCost,
              value: Money.format(report.costMinor),
              foreground: AppColors.warningFg,
              background: AppColors.warningBg,
            ),
            KpiCard(
              icon: Icons.trending_up,
              label: ReportsStrings.kpiProfit,
              value: Money.format(report.profitMinor),
              foreground: report.profitMinor < 0 ? AppColors.dangerFg : AppColors.successFg,
              background: report.profitMinor < 0 ? AppColors.dangerBg : AppColors.successBg,
            ),
            KpiCard(
              icon: Icons.percent,
              label: ReportsStrings.kpiMargin,
              value: ReportFormat.percent(report.profitMinor, report.revenueMinor),
              foreground: AppColors.rxFg,
              background: AppColors.rxBg,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ReportCard(
          title: ReportsStrings.productProfit,
          note: ReportsStrings.profitNote,
          child: ReportTable(
            columns: const [
              ReportColumn(ReportsStrings.colProduct, flex: ReportsLayout.nameFlex),
              ReportColumn(ReportsStrings.colUnits, flex: ReportsLayout.numberFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colRevenue, flex: ReportsLayout.moneyFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colCost, flex: ReportsLayout.moneyFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colProfit, flex: ReportsLayout.moneyFlex, alignEnd: true),
              ReportColumn(ReportsStrings.colMargin, flex: ReportsLayout.numberFlex, alignEnd: true),
            ],
            rows: [
              for (final product in report.byProfit)
                [
                  ReportText(product.name, bold: true),
                  ReportText('${product.unitsSold}'),
                  ReportText(Money.format(product.revenueMinor)),
                  ReportText(Money.format(product.costMinor)),
                  ReportText(
                    Money.format(product.profitMinor),
                    bold: true,
                    color: product.profitMinor < 0 ? AppColors.dangerFg : null,
                  ),
                  ReportText(ReportFormat.percent(product.profitMinor, product.revenueMinor)),
                ],
            ],
            footer: [
              const ReportText(ReportsStrings.totalRow, bold: true),
              const ReportText(''),
              ReportText(Money.format(report.revenueMinor), bold: true),
              ReportText(Money.format(report.costMinor), bold: true),
              ReportText(Money.format(report.profitMinor), bold: true, color: profitColor),
              ReportText(ReportFormat.percent(report.profitMinor, report.revenueMinor), bold: true),
            ],
          ),
        ),
      ],
    );
  }
}
