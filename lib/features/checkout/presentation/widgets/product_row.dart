import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product.dart';
import 'product_badges.dart';
import 'status_pill.dart';

class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.product, required this.onAdd});

  static const double _disabledOpacity = 0.5;
  static const int _nameFlex = 5;
  static const int _genericFlex = 4;

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final sellable = product.isSellable(now);

    return Opacity(
      opacity: sellable ? 1 : _disabledOpacity,
      child: InkWell(
        onTap: sellable ? onAdd : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
          child: Row(
            children: [
              Expanded(
                flex: _nameFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppDimens.spaceXs),
                    Wrap(
                      spacing: AppDimens.spaceXs,
                      runSpacing: AppDimens.spaceXs,
                      children: [
                        if (product.requiresPrescription) const RxBadge(),
                        ExpiryBadge(product: product, now: now),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: _genericFlex,
                child: Text(
                  product.genericName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              SizedBox(
                width: AppDimens.tableStockColumnWidth,
                child: Center(child: _StockCount(product: product)),
              ),
              SizedBox(
                width: AppDimens.tableActionColumnWidth,
                child: Center(
                  child: IconButton(
                    tooltip: AppStrings.addToCart,
                    color: AppColors.primary,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: sellable ? onAdd : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockCount extends StatelessWidget {
  const _StockCount({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = product.isOutOfStock
        ? (AppColors.dangerFg, AppColors.dangerBg)
        : product.isLowStock
            ? (AppColors.warningFg, AppColors.warningBg)
            : (AppColors.successFg, AppColors.successBg);
    return StatusPill(label: '${product.sellableStock}', foreground: fg, background: bg);
  }
}
