import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/dashboard_summary.dart';

/// Seven-day bar chart drawn with plain widgets (no chart package).
/// The last bar (today) is highlighted.
class SalesBarChart extends StatelessWidget {
  const SalesBarChart({super.key, required this.days});

  final List<DailySales> days;

  @override
  Widget build(BuildContext context) {
    final maxMinor = days.fold(0, (max, day) => day.totalMinor > max ? day.totalMinor : max);

    return SizedBox(
      height: AppDimens.chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, day) in days.indexed)
            Expanded(
              child: _Bar(day: day, maxMinor: maxMinor, highlighted: index == days.length - 1),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.maxMinor, required this.highlighted});

  static const int _thousand = 1000;
  static const int _hundred = 100;

  final DailySales day;
  final int maxMinor;
  final bool highlighted;

  /// "28.6k" or "950", in major units. Display only.
  String _compact(int minor) {
    final major = minor ~/ AppConfig.minorUnitsPerMajor;
    if (major >= _thousand) return '${major ~/ _thousand}.${(major % _thousand) ~/ _hundred}k';
    return '$major';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const range = AppDimens.chartBarMaxHeight - AppDimens.chartBarMinHeight;
    final barHeight = maxMinor == 0
        ? AppDimens.chartBarMinHeight
        : AppDimens.chartBarMinHeight + range * day.totalMinor / maxMinor;

    return Tooltip(
      message: '${AppDates.short(day.date)}: ${Money.format(day.totalMinor)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _compact(day.totalMinor),
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Container(
            height: barHeight,
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            decoration: BoxDecoration(
              color: highlighted ? AppColors.primary : AppColors.chartBar,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSm / 2)),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            AppDates.weekdayShort(day.date),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
