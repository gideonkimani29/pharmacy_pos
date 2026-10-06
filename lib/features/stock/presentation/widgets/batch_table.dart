import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../../domain/entities/stock_batch.dart';
import '../bloc/stock_cubit.dart';
import '../stock_constants.dart';
import 'adjust_stock_dialog.dart';
import 'stock_shared.dart';

class BatchTable extends StatelessWidget {
  const BatchTable({super.key, required this.compact});

  /// Hides cost, price and received columns on narrow windows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = StockHeaderRow.style(context);
    return StockTableCard(
      header: StockHeaderRow(
        children: [
          Expanded(flex: StockLayout.nameFlex, child: Text(StockStrings.colMedicine, style: style)),
          SizedBox(width: StockLayout.batchColumnWidth, child: Text(StockStrings.colBatch, style: style)),
          SizedBox(width: StockLayout.expiryColumnWidth, child: Text(StockStrings.colExpiry, style: style)),
          SizedBox(width: StockLayout.onHandColumnWidth, child: Text(StockStrings.colOnHand, style: style)),
          if (!compact) ...[
            SizedBox(width: StockLayout.moneyColumnWidth, child: Text(StockStrings.colCost, style: style)),
            SizedBox(width: StockLayout.moneyColumnWidth, child: Text(StockStrings.colPrice, style: style)),
            SizedBox(width: StockLayout.receivedColumnWidth, child: Text(StockStrings.colReceived, style: style)),
          ],
          SizedBox(
            width: StockLayout.actionColumnWidth,
            child: Center(child: Text(StockStrings.colAction, style: style)),
          ),
        ],
      ),
      body: BlocBuilder<StockCubit, StockState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.batches != current.batches ||
            previous.query != current.query ||
            previous.filter != current.filter ||
            previous.asOf != current.asOf,
        builder: (context, state) {
          if (state.batches.isEmpty) {
            if (state.status == StockStatus.failure) {
              return StockMessage(
                icon: Icons.cloud_off_outlined,
                title: StockStrings.loadFailed,
                detail: state.failure?.message,
                actionLabel: StockStrings.retry,
                onAction: () => context.read<StockCubit>().load(),
              );
            }
            if (state.status == StockStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return const StockMessage(
              icon: Icons.inventory_2_outlined,
              title: StockStrings.emptyTitle,
              detail: StockStrings.emptyHint,
            );
          }

          final rows = state.visibleBatches;
          if (rows.isEmpty) {
            return const StockMessage(icon: Icons.search_off_outlined, title: StockStrings.noMatches);
          }

          final fefoIds = state.fefoNextBatchIds;
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _BatchRow(
              key: ValueKey(rows[index].id),
              batch: rows[index],
              asOf: state.asOf,
              isFefoNext: fefoIds.contains(rows[index].id),
              compact: compact,
            ),
          );
        },
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({
    super.key,
    required this.batch,
    required this.asOf,
    required this.isFefoNext,
    required this.compact,
  });

  final StockBatch batch;
  final DateTime asOf;
  final bool isFefoNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final expiry = batch.expiryAt(asOf);

    return Opacity(
      opacity: batch.isDepleted ? StockLayout.inactiveOpacity : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
        child: Row(
          children: [
            Expanded(
              flex: StockLayout.nameFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.medicineName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (isFefoNext)
                    const Padding(
                      padding: EdgeInsets.only(top: AppDimens.spaceXs),
                      child: StatusPill(
                        label: StockStrings.fefoNext,
                        foreground: AppColors.successFg,
                        background: AppColors.successBg,
                        icon: Icons.bolt,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: StockLayout.batchColumnWidth, child: Text(batch.batchNumber)),
            SizedBox(
              width: StockLayout.expiryColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppDates.short(batch.expiryDate)),
                  if (!batch.isDepleted)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimens.spaceXs),
                      child: BatchExpiryPill(expiry: expiry),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: StockLayout.onHandColumnWidth,
              child: batch.isDepleted
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(
                        label: StockStrings.emptyPill,
                        foreground: AppColors.neutralFg,
                        background: AppColors.neutralBg,
                      ),
                    )
                  : Text(
                      StockStrings.onHandOf(batch.quantityOnHand, batch.quantityReceived),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
            if (!compact) ...[
              SizedBox(width: StockLayout.moneyColumnWidth, child: Text(Money.format(batch.unitCostMinor))),
              SizedBox(width: StockLayout.moneyColumnWidth, child: Text(Money.format(batch.sellingPriceMinor))),
              SizedBox(
                width: StockLayout.receivedColumnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppDates.short(batch.receivedOn)),
                    Text(batch.supplierName, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: StockLayout.actionColumnWidth,
              child: Center(
                child: Tooltip(
                  message: StockStrings.adjustTooltip,
                  child: TextButton(
                    onPressed: () => AdjustStockDialog.show(context, batch: batch, asOf: asOf),
                    child: const Text(StockStrings.adjust),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
