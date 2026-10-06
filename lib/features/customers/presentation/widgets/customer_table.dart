import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../../domain/entities/customer_account.dart';
import '../bloc/customer_accounts_cubit.dart';
import '../customers_constants.dart';
import 'customer_form_dialog.dart';
import 'receive_payment_dialog.dart';

class CustomerTable extends StatelessWidget {
  const CustomerTable({super.key, required this.compact});

  /// Hides credit limit, available credit and last purchase on narrow windows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          _HeaderRow(compact: compact),
          const Divider(height: 1),
          Expanded(child: _Body(compact: compact)),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
      child: Row(
        children: [
          Expanded(flex: CustomersLayout.nameFlex, child: Text(CustomersStrings.colCustomer, style: style)),
          if (!compact)
            SizedBox(width: CustomersLayout.limitColumnWidth, child: Text(CustomersStrings.colLimit, style: style)),
          SizedBox(width: CustomersLayout.balanceColumnWidth, child: Text(CustomersStrings.colBalance, style: style)),
          if (!compact) ...[
            SizedBox(
              width: CustomersLayout.availableColumnWidth,
              child: Text(CustomersStrings.colAvailable, style: style),
            ),
            SizedBox(
              width: CustomersLayout.lastPurchaseColumnWidth,
              child: Text(CustomersStrings.colLastPurchase, style: style),
            ),
          ],
          SizedBox(
            width: CustomersLayout.activeColumnWidth,
            child: Center(child: Text(CustomersStrings.colActive, style: style)),
          ),
          SizedBox(
            width: compact ? CustomersLayout.actionsColumnCompactWidth : CustomersLayout.actionsColumnWidth,
            child: Center(child: Text(CustomersStrings.colActions, style: style)),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerAccountsCubit, CustomerAccountsState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.accounts != current.accounts ||
          previous.query != current.query ||
          previous.filter != current.filter,
      builder: (context, state) {
        final visible = state.visible;

        if (state.accounts.isEmpty) {
          if (state.status == CustomerAccountsStatus.failure) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              title: CustomersStrings.loadFailed,
              detail: state.failure?.message,
              actionLabel: CustomersStrings.retry,
              onAction: () => context.read<CustomerAccountsCubit>().load(),
            );
          }
          if (state.status == CustomerAccountsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return const _Message(
            icon: Icons.people_outline,
            title: CustomersStrings.emptyTitle,
            detail: CustomersStrings.emptyHint,
          );
        }

        if (visible.isEmpty) {
          return _Message(
            icon: Icons.search_off_outlined,
            title: state.query.trim().isEmpty
                ? CustomersStrings.noMatchesFilter
                : CustomersStrings.noMatches(state.query.trim()),
          );
        }

        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _CustomerRow(
            key: ValueKey(visible[index].id),
            account: visible[index],
            compact: compact,
          ),
        );
      },
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({super.key, required this.account, required this.compact});

  final CustomerAccount account;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final cubit = context.read<CustomerAccountsCubit>();
    final lastPurchase = account.lastPurchaseOn;

    return Opacity(
      opacity: account.isActive ? 1 : CustomersLayout.inactiveOpacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
        child: Row(
          children: [
            Expanded(
              flex: CustomersLayout.nameFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    account.email.isEmpty ? account.phone : '${account.phone}  ·  ${account.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ],
              ),
            ),
            if (!compact)
              SizedBox(
                width: CustomersLayout.limitColumnWidth,
                child: Text(
                  account.creditLimitMinor == 0 ? CustomersStrings.noCredit : Money.format(account.creditLimitMinor),
                ),
              ),
            SizedBox(
              width: CustomersLayout.balanceColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Money.format(account.balanceMinor),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: account.owes ? AppColors.dangerFg : AppColors.textPrimary,
                    ),
                  ),
                  if (account.isOverLimit)
                    const Padding(
                      padding: EdgeInsets.only(top: AppDimens.spaceXs),
                      child: StatusPill(
                        label: CustomersStrings.overLimitPill,
                        foreground: AppColors.dangerFg,
                        background: AppColors.dangerBg,
                      ),
                    ),
                ],
              ),
            ),
            if (!compact) ...[
              SizedBox(
                width: CustomersLayout.availableColumnWidth,
                child: Text(Money.format(account.availableCreditMinor)),
              ),
              SizedBox(
                width: CustomersLayout.lastPurchaseColumnWidth,
                child: Text(lastPurchase == null ? CustomersStrings.never : AppDates.short(lastPurchase)),
              ),
            ],
            SizedBox(
              width: CustomersLayout.activeColumnWidth,
              child: Center(
                child: Tooltip(
                  message: CustomersStrings.activeTooltip,
                  child: Switch(value: account.isActive, onChanged: (_) => cubit.toggleActive(account)),
                ),
              ),
            ),
            SizedBox(
              width: compact ? CustomersLayout.actionsColumnCompactWidth : CustomersLayout.actionsColumnWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (account.owes)
                    Tooltip(
                      message: CustomersStrings.receivePayment,
                      child: IconButton(
                        icon: const Icon(Icons.payments_outlined, color: AppColors.primary),
                        onPressed: () => ReceivePaymentDialog.show(context, account: account),
                      ),
                    ),
                  IconButton(
                    tooltip: CustomersStrings.editTooltip,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => CustomerFormDialog.show(context, existing: account),
                  ),
                ],
              ),
            ),
          ],
        ),
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
