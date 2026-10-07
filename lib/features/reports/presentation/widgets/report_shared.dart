import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../reports_constants.dart';

/// Wraps a row of KPI cards to a common width.
class ReportKpiRow extends StatelessWidget {
  const ReportKpiRow({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.spaceLg,
      runSpacing: AppDimens.spaceLg,
      children: [for (final card in cards) SizedBox(width: ReportsLayout.kpiWidth, child: card)],
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.title, required this.child, this.note});

  final String title;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          child,
          if (note != null)
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class ReportColumn {
  const ReportColumn(this.label, {this.flex = 1, this.alignEnd = false});

  final String label;
  final int flex;
  final bool alignEnd;
}

/// Plain text cell. Alignment comes from the column, not the cell.
class ReportText extends StatelessWidget {
  const ReportText(this.text, {super.key, this.bold = false, this.color});

  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color,
          ),
    );
  }
}

/// Header, rows and an optional totals row. Scrolls sideways on narrow windows
/// instead of squashing the columns.
class ReportTable extends StatelessWidget {
  const ReportTable({super.key, required this.columns, required this.rows, this.footer});

  final List<ReportColumn> columns;
  final List<List<Widget>> rows;
  final List<Widget>? footer;

  Widget _row(List<Widget> cells, {Color? background}) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: columns[i].flex,
              child: Align(
                alignment: columns[i].alignEnd ? Alignment.centerRight : Alignment.centerLeft,
                child: cells[i],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final table = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            _row(
              [for (final column in columns) Text(column.label, style: headerStyle)],
              background: AppColors.surfaceMuted,
            ),
            for (final cells in rows) ...[
              const Divider(height: 1),
              _row(cells),
            ],
            if (footer != null) ...[
              const Divider(height: 1),
              _row(footer!, background: AppColors.surfaceMuted),
            ],
          ],
        );

        if (constraints.maxWidth >= ReportsLayout.tableMinWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: ReportsLayout.tableMinWidth, child: table),
        );
      },
    );
  }
}
