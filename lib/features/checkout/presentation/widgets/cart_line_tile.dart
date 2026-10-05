import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/cart_item.dart';
import 'product_badges.dart';

/// Shared column geometry so the header and every line align exactly.
class CartRowLayout extends StatelessWidget {
  const CartRowLayout({
    super.key,
    required this.item,
    required this.quantity,
    required this.total,
    this.action,
  });

  final Widget item;
  final Widget quantity;
  final Widget total;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: item),
        const SizedBox(width: AppDimens.spaceSm),
        SizedBox(width: AppDimens.cartQtyColumnWidth, child: Center(child: quantity)),
        const SizedBox(width: AppDimens.spaceSm),
        SizedBox(
          width: AppDimens.cartTotalColumnWidth,
          child: Align(alignment: Alignment.centerRight, child: total),
        ),
        SizedBox(width: AppDimens.cartRemoveColumnWidth, child: action),
      ],
    );
  }
}

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.item,
    required this.enabled,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final bool enabled;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = item.product;
    final batch = product.nextBatchNumber;
    final unitPrice = AppStrings.lineUnitPrice(Money.format(product.unitPriceMinor));
    final detail = batch == null ? unitPrice : '${AppStrings.batchLabel(batch)}  ·  $unitPrice';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: CartRowLayout(
        item: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (product.requiresPrescription) ...[
                  const RxBadge(),
                  const SizedBox(width: AppDimens.spaceXs),
                ],
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        quantity: _QuantityStepper(quantity: item.quantity, enabled: enabled, onChanged: onQuantityChanged),
        total: Text(
          Money.format(item.lineTotalMinor),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        action: IconButton(
          tooltip: AppStrings.removeItem,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
          onPressed: enabled ? onRemove : null,
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.enabled, required this.onChanged});

  static const double _countWidth = 36;

  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          tooltip: AppStrings.decreaseQuantity,
          onPressed: enabled ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: _countWidth,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          tooltip: AppStrings.increaseQuantity,
          onPressed: enabled ? () => onChanged(quantity + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppDimens.stepperButtonSize,
      height: AppDimens.stepperButtonSize,
      child: IconButton.outlined(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: AppDimens.iconSm,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
