import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/product.dart';
import 'status_pill.dart';

class RxBadge extends StatelessWidget {
  const RxBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusPill(
      label: AppStrings.rxBadge,
      foreground: AppColors.rxFg,
      background: AppColors.rxBg,
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (product.isOutOfStock) {
      return const StatusPill(
        label: AppStrings.stockOut,
        foreground: AppColors.dangerFg,
        background: AppColors.dangerBg,
      );
    }
    if (product.isLowStock) {
      return StatusPill(
        label: AppStrings.stockLow(product.sellableStock),
        foreground: AppColors.warningFg,
        background: AppColors.warningBg,
      );
    }
    return StatusPill(
      label: AppStrings.stockIn(product.sellableStock),
      foreground: AppColors.successFg,
      background: AppColors.successBg,
    );
  }
}

/// Colour-codes the nearest batch expiry using the 30/60/90 day bands.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.product, required this.now});

  final Product product;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final expiry = product.nearestExpiry;
    final status = product.expiryStatus(now);
    if (expiry == null || status == ExpiryStatus.none) return const SizedBox.shrink();

    final (Color fg, Color bg) = switch (status) {
      ExpiryStatus.expired || ExpiryStatus.within30 => (AppColors.dangerFg, AppColors.dangerBg),
      ExpiryStatus.within60 => (AppColors.warningFg, AppColors.warningBg),
      ExpiryStatus.within90 => (AppColors.infoFg, AppColors.infoBg),
      ExpiryStatus.ok || ExpiryStatus.none => (AppColors.neutralFg, AppColors.neutralBg),
    };

    final label = status == ExpiryStatus.expired
        ? AppStrings.expired
        : '${AppStrings.expiryPrefix} ${AppDates.short(expiry)}';

    return StatusPill(label: label, foreground: fg, background: bg);
  }
}
