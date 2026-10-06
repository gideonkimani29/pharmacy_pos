import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../bloc/stock_cubit.dart';
import '../stock_constants.dart';
import 'stock_shared.dart';

/// "By medicine" view: one row per medicine with sellable stock vs reorder level.
class MedicineStockTable extends StatelessWidget {
  const MedicineStockTable({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = StockHeaderRow.style(context);
    return StockTableCard(
      header: StockHeaderRow(
        children: [
          Expanded(flex: StockLayout.nameFlex, child: Text(StockStrings.colMedicine, style: style)),
          SizedBox(
            width: StockLayout.sellableColumnWidth,
            child: Center(child: Text(StockStrings.colSellable, style: style)),
          ),
          SizedBox(
            width: StockLayout.totalColumnWidth,
            child: Center(child: Text(StockStrings.colTotal, style: style)),
          ),
          if (!compact)
            SizedBox(width: StockLayout.batchesColumnWidth, child: Text(StockStrings.colBatches, style: style)),
          SizedBox(
            width: StockLayout.nextExpiryColumnWidth,
            child: Text(StockStrings.colNextExpiry, style: style),
          ),
          if (!compact)
            SizedBox(
              width: StockLayout.reorderColumnWidth,
              child: Center(child: Text(StockStrings.colReorder, style: style)),
            ),
        ],
      ),
      body: BlocBuilder<StockCubit, StockState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.batches != current.batches ||
            previous.query != current.query ||
            previous.asOf != current.asOf,
        builder: (context, state) {
          if (state.batches.isEmpty) {
            if (state.status == StockStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const StockMessage(
              icon: Icons.inventory_2_outlined,
              title: StockStrings.emptyTitle,
              detail: StockStrings.emptyHint,
            );
          }

          final rows = state.summaries;
          if (rows.isEmpty) {
            return const StockMessage(icon: Icons.search_off_outlined, title: StockStrings.noMatches);
          }

          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _SummaryRow(summary: rows[index], compact: compact),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary, required this.compact});

  final MedicineStockSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color fg, Color bg, String label) = switch (summary.level) {
      SellableLevel.out => (AppColors.dangerFg, AppColors.dangerBg, StockStrings.stockOutPill),
      SellableLevel.low => (AppColors.warningFg, AppColors.warningBg, '${summary.sellableUnits}'),
      SellableLevel.ok => (AppColors.successFg, AppColors.successBg, '${summary.sellableUnits}'),
    };
    final nextExpiry = summary.nextExpiry;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
      child: Row(
        children: [
          Expanded(
            flex: StockLayout.nameFlex,
            child: Text(
              summary.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: StockLayout.sellableColumnWidth,
            child: Center(child: StatusPill(label: label, foreground: fg, background: bg)),
          ),
          SizedBox(
            width: StockLayout.totalColumnWidth,
            child: Center(child: Text('${summary.totalUnits}')),
          ),
          if (!compact)
            SizedBox(
              width: StockLayout.batchesColumnWidth,
              child: Text(StockStrings.batchCount(summary.batchCount)),
            ),
          SizedBox(
            width: StockLayout.nextExpiryColumnWidth,
            child: Text(nextExpiry == null ? StockStrings.noNextExpiry : AppDates.short(nextExpiry)),
          ),
          if (!compact)
            SizedBox(
              width: StockLayout.reorderColumnWidth,
              child: Center(child: Text('${summary.reorderLevel}')),
            ),
        ],
      ),
    );
  }
}
