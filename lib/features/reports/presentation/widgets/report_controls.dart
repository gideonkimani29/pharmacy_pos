import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/report_range.dart';
import '../bloc/reports_cubit.dart';
import '../reports_constants.dart';

/// Period chips, the chosen range, and the report switch.
class ReportControls extends StatelessWidget {
  const ReportControls({super.key});

  static const int _maxPickableYears = 5;

  static String _presetLabel(RangePreset preset) => switch (preset) {
        RangePreset.today => ReportsStrings.presetToday,
        RangePreset.last7 => ReportsStrings.presetLast7,
        RangePreset.last30 => ReportsStrings.presetLast30,
        RangePreset.thisMonth => ReportsStrings.presetThisMonth,
        RangePreset.custom => ReportsStrings.presetCustom,
      };

  Future<void> _pickRange(BuildContext context, ReportsState state) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      helpText: ReportsStrings.pickRangeHelp,
      firstDate: DateTime(today.year - _maxPickableYears),
      lastDate: today,
      initialDateRange: DateTimeRange(start: state.range.from, end: state.range.to),
    );
    if (picked == null || !context.mounted) return;
    context.read<ReportsCubit>().setCustomRange(ReportRange(from: picked.start, to: picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ReportsCubit>();

    return BlocBuilder<ReportsCubit, ReportsState>(
      buildWhen: (previous, current) =>
          previous.preset != current.preset || previous.range != current.range || previous.tab != current.tab,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final preset in RangePreset.values)
                  ChoiceChip(
                    avatar: preset == RangePreset.custom ? const Icon(Icons.date_range, size: AppDimens.iconSm) : null,
                    label: Text(_presetLabel(preset)),
                    selected: state.preset == preset,
                    onSelected: (_) => preset == RangePreset.custom ? _pickRange(context, state) : cubit.setPreset(preset),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: AppDimens.spaceSm),
                  child: Text(
                    ReportsStrings.rangeLabel(AppDates.short(state.range.from), AppDates.short(state.range.to)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<ReportTab>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ReportTab.sales,
                    label: Text(ReportsStrings.tabSales),
                    icon: Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: ReportTab.profit,
                    label: Text(ReportsStrings.tabProfit),
                    icon: Icon(Icons.trending_up),
                  ),
                  ButtonSegment(
                    value: ReportTab.losses,
                    label: Text(ReportsStrings.tabLosses),
                    icon: Icon(Icons.delete_outline),
                  ),
                ],
                selected: {state.tab},
                onSelectionChanged: (selection) => cubit.setTab(selection.first),
              ),
            ),
          ],
        );
      },
    );
  }
}
