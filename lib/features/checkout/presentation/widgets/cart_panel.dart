import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sale_type.dart';
import '../bloc/cart_bloc.dart';
import 'cart_line_tile.dart';

/// Right-hand pane: sale type, line items, prescription check, totals, checkout.
class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.onCheckout,
    required this.onClear,
    required this.onEditDiscount,
  });

  final VoidCallback onCheckout;
  final VoidCallback onClear;
  final VoidCallback onEditDiscount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(state: state, onClear: onClear),
              // Scrolls when the window is short.
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppDimens.spaceLg),
                  children: [
                    _SaleTypeToggle(state: state),
                    const SizedBox(height: AppDimens.spaceLg),
                    const _ColumnHeader(),
                    const Divider(height: 1),
                    if (state.isEmpty) const _EmptyCart() else _Lines(state: state),
                    if (state.requiresPrescriptionCheck) ...[
                      const SizedBox(height: AppDimens.spaceMd),
                      _PrescriptionCheck(state: state),
                    ],
                  ],
                ),
              ),
              // Always visible.
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Totals(state: state, onEditDiscount: onEditDiscount),
                    const SizedBox(height: AppDimens.spaceLg),
                    _CheckoutButton(state: state, onCheckout: onCheckout),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onClear});

  static const int _disabledAlpha = 120;

  final CartState state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.cartHeader,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceSm),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, color: AppColors.onPrimary),
          const SizedBox(width: AppDimens.spaceMd),
          Text(
            AppStrings.cartItemsTitle(state.unitCount),
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onPrimary,
              disabledForegroundColor: AppColors.onPrimary.withAlpha(_disabledAlpha),
            ),
            onPressed: state.isEmpty || state.isSubmitting ? null : onClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text(AppStrings.clearSale),
          ),
        ],
      ),
    );
  }
}

class _SaleTypeToggle extends StatelessWidget {
  const _SaleTypeToggle({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.saleType, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppDimens.spaceXs),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<SaleType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: SaleType.cash, label: Text(AppStrings.saleTypeCash)),
              ButtonSegment(value: SaleType.credit, label: Text(AppStrings.saleTypeCredit)),
            ],
            selected: {state.saleType},
            onSelectionChanged: state.isSubmitting
                ? null
                : (selection) => context.read<CartBloc>().add(CartSaleTypeChanged(selection.first)),
          ),
        ),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: CartRowLayout(
        item: Text(AppStrings.columnItem, style: style),
        quantity: Text(AppStrings.columnQty, style: style),
        total: Text(AppStrings.columnTotal, style: style),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CartBloc>();
    return Column(
      children: [
        for (final (index, item) in state.items.indexed) ...[
          if (index > 0) const Divider(height: 1),
          CartLineTile(
            key: ValueKey(item.product.id),
            item: item,
            enabled: !state.isSubmitting,
            onQuantityChanged: (quantity) =>
                bloc.add(CartQuantityChanged(productId: item.product.id, quantity: quantity)),
            onRemove: () => bloc.add(CartItemRemoved(item.product.id)),
          ),
        ],
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  static const double _iconSize = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppDimens.emptyCartHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_basket_outlined, size: _iconSize, color: AppColors.textSecondary),
            const SizedBox(height: AppDimens.spaceMd),
            Text(AppStrings.cartEmptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              AppStrings.cartEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionCheck extends StatelessWidget {
  const _PrescriptionCheck({required this.state});

  final CartState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.rxBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.rxBannerTitle,
              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.rxFg, fontWeight: FontWeight.w700),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(AppStrings.rxVerifiedLabel),
              value: state.prescriptionVerified,
              onChanged: state.isSubmitting
                  ? null
                  : (value) => context
                      .read<CartBloc>()
                      .add(CartPrescriptionToggled(verified: value ?? false)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.state, required this.onEditDiscount});

  final CartState state;
  final VoidCallback onEditDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = state.totals;
    final muted = theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary);

    return Column(
      children: [
        _line(AppStrings.subtotal, Text(Money.format(totals.subtotalMinor), style: muted), muted),
        _line(
          AppStrings.discount,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '-${Money.format(totals.discountMinor)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: totals.discountMinor > 0 ? AppColors.dangerFg : AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: AppStrings.editDiscount,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: AppDimens.iconSm),
                onPressed: state.isEmpty || state.isSubmitting ? null : onEditDiscount,
              ),
            ],
          ),
          muted,
        ),
        if (totals.taxMinor > 0)
          _line(AppStrings.tax, Text(Money.format(totals.taxMinor), style: muted), muted),
        const SizedBox(height: AppDimens.spaceSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(AppStrings.total, style: theme.textTheme.titleMedium),
            Text(
              Money.format(totals.totalMinor),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _line(String label, Widget value, TextStyle? labelStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: labelStyle), value],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({required this.state, required this.onCheckout});

  final CartState state;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final fontSize = Theme.of(context).textTheme.titleMedium?.fontSize;
    return SizedBox(
      height: AppDimens.payButtonHeight,
      child: FilledButton(
        // Stays tappable when the cart is empty, Rx is unchecked or a credit
        // sale has no customer, so the cashier gets a reason instead of a dead button.
        onPressed: state.isSubmitting ? null : onCheckout,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.isSubmitting) ...[
              const SizedBox(
                width: AppDimens.iconSm,
                height: AppDimens.iconSm,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Text(AppStrings.processing, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700)),
            ] else ...[
              const Icon(Icons.send),
              const SizedBox(width: AppDimens.spaceMd),
              Text(
                AppStrings.proceedToCheckout,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              const Text(AppStrings.shortcutPayKey),
            ],
          ],
        ),
      ),
    );
  }
}
