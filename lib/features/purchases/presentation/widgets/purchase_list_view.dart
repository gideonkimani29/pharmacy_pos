import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../../domain/entities/purchase.dart';
import '../bloc/purchases_cubit.dart';
import '../purchases_constants.dart';

class PurchaseListView extends StatelessWidget {
  const PurchaseListView({super.key, required this.onNew});

  static const double _gap = AppDimens.spaceLg;

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PurchasesStrings.title,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    PurchasesStrings.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text(PurchasesStrings.newPurchase),
            ),
          ],
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: BlocBuilder<PurchasesCubit, PurchasesState>(
            builder: (context, state) {
              if (state.purchases.isEmpty) {
                if (state.status == PurchasesStatus.failure) {
                  return _Message(
                    icon: Icons.cloud_off_outlined,
                    title: PurchasesStrings.loadFailed,
                    detail: state.failure?.message,
                    actionLabel: PurchasesStrings.retry,
                    onAction: () => context.read<PurchasesCubit>().load(),
                  );
                }
                if (state.status == PurchasesStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const _Message(
                  icon: Icons.inventory_2_outlined,
                  title: PurchasesStrings.emptyTitle,
                  detail: PurchasesStrings.emptyHint,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.status == PurchasesStatus.loading) const LinearProgressIndicator(),
                  Wrap(
                    spacing: _gap,
                    runSpacing: _gap,
                    children: [
                      SizedBox(
                        width: PurchasesLayout.detailsPaneWidth,
                        child: KpiCard(
                          icon: Icons.inventory_2_outlined,
                          label: PurchasesStrings.kpiPurchases,
                          value: '${state.purchases.length}',
                          foreground: AppColors.infoFg,
                          background: AppColors.infoBg,
                        ),
                      ),
                      SizedBox(
                        width: PurchasesLayout.detailsPaneWidth,
                        child: KpiCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: PurchasesStrings.kpiOwed,
                          value: Money.format(state.owedToSuppliersMinor),
                          foreground: AppColors.warningFg,
                          background: AppColors.warningBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _gap),
                  Expanded(child: _Table(purchases: state.purchases)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.purchases});

  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
            child: Row(
              children: [
                Expanded(flex: PurchasesLayout.dateFlex, child: Text(PurchasesStrings.colDate, style: headerStyle)),
                Expanded(
                  flex: PurchasesLayout.referenceFlex,
                  child: Text(PurchasesStrings.colReference, style: headerStyle),
                ),
                Expanded(
                  flex: PurchasesLayout.supplierFlex,
                  child: Text(PurchasesStrings.colSupplier, style: headerStyle),
                ),
                Expanded(flex: PurchasesLayout.itemsFlex, child: Text(PurchasesStrings.colItems, style: headerStyle)),
                Expanded(
                  flex: PurchasesLayout.totalFlex,
                  child: Text(PurchasesStrings.colTotal, textAlign: TextAlign.right, style: headerStyle),
                ),
                SizedBox(
                  width: PurchasesLayout.statusColumnWidth,
                  child: Center(child: Text(PurchasesStrings.colStatus, style: headerStyle)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: purchases.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => _Row(purchase: purchases[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final paid = purchase.paymentStatus == PurchasePaymentStatus.paid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
      child: Row(
        children: [
          Expanded(flex: PurchasesLayout.dateFlex, child: Text(AppDates.short(purchase.receivedOn))),
          Expanded(
            flex: PurchasesLayout.referenceFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.reference, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(PurchasesStrings.invoiceLabel(purchase.invoiceNumber), style: muted),
              ],
            ),
          ),
          Expanded(
            flex: PurchasesLayout.supplierFlex,
            child: Text(purchase.supplierName, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: PurchasesLayout.itemsFlex,
            child: Text(PurchasesStrings.itemsSummary(purchase.lineCount, purchase.unitCount), style: muted),
          ),
          Expanded(
            flex: PurchasesLayout.totalFlex,
            child: Text(
              Money.format(purchase.totalMinor),
              textAlign: TextAlign.right,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: PurchasesLayout.statusColumnWidth,
            child: Center(
              child: StatusPill(
                label: paid ? PurchasesStrings.statusPaid : PurchasesStrings.statusOnCredit,
                foreground: paid ? AppColors.successFg : AppColors.warningFg,
                background: paid ? AppColors.successBg : AppColors.warningBg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.detail, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.emptyStateIconSize, color: AppColors.textSecondary),
          const SizedBox(height: AppDimens.spaceMd),
          Text(title, style: theme.textTheme.titleMedium),
          if (detail != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(detail!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppDimens.spaceLg),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
