import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../../domain/entities/losses_report.dart';
import '../reports_constants.dart';
import 'report_shared.dart';

class LossesReportView extends StatelessWidget {
  const LossesReportView({super.key, required this.report});

  final LossesReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportKpiRow(
          cards: [
            KpiCard(
              icon: Icons.delete_outline,
              label: ReportsStrings.kpiTotalLoss,
              value: Money.format(report.totalLossMinor),
              foreground: AppColors.dangerFg,
              background: AppColors.dangerBg,
            ),
            KpiCard(
              icon: Icons.hourglass_bottom,
              label: ReportsStrings.kpiExpired,
              value: Money.format(report.lossFor(LossReason.expired)),
              foreground: AppColors.warningFg,
              background: AppColors.warningBg,
            ),
            KpiCard(
              icon: Icons.broken_image_outlined,
              label: ReportsStrings.kpiDamaged,
              value: Money.format(report.lossFor(LossReason.damaged)),
              foreground: AppColors.rxFg,
              background: AppColors.rxBg,
            ),
            KpiCard(
              icon: Icons.fact_check_outlined,
              label: ReportsStrings.kpiShortage,
              value: Money.format(report.lossFor(LossReason.countShortage)),
              foreground: AppColors.infoFg,
              background: AppColors.infoBg,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ReportCard(
          title: ReportsStrings.lossesTitle,
          child: report.rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    0,
                    AppDimens.spaceLg,
                    AppDimens.spaceXl,
                  ),
                  child: Text(
                    ReportsStrings.noLosses,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ReportTable(
                  columns: const [
                    ReportColumn(ReportsStrings.colDate, flex: ReportsLayout.dateFlex),
                    ReportColumn(ReportsStrings.colMedicine, flex: ReportsLayout.nameFlex),
                    ReportColumn(ReportsStrings.colBatch, flex: ReportsLayout.numberFlex),
                    ReportColumn(ReportsStrings.colQuantity, flex: ReportsLayout.numberFlex, alignEnd: true),
                    ReportColumn(ReportsStrings.colUnitCost, flex: ReportsLayout.moneyFlex, alignEnd: true),
                    ReportColumn(ReportsStrings.colLoss, flex: ReportsLayout.moneyFlex, alignEnd: true),
                    ReportColumn(ReportsStrings.colReason, flex: ReportsLayout.moneyFlex),
                  ],
                  rows: [
                    for (final row in report.rows)
                      [
                        ReportText(AppDates.short(row.date)),
                        ReportText(row.medicineName, bold: true),
                        ReportText(row.batchNumber),
                        ReportText('${row.quantity}'),
                        ReportText(Money.format(row.unitCostMinor)),
                        ReportText(Money.format(row.lossMinor), bold: true, color: AppColors.dangerFg),
                        ReportText(ReportsStrings.lossReasonLabel(row.reason)),
                      ],
                  ],
                  footer: [
                    const ReportText(ReportsStrings.totalRow, bold: true),
                    const ReportText(''),
                    const ReportText(''),
                    const ReportText(''),
                    const ReportText(''),
                    ReportText(Money.format(report.totalLossMinor), bold: true, color: AppColors.dangerFg),
                    const ReportText(''),
                  ],
                ),
        ),
      ],
    );
  }
}
