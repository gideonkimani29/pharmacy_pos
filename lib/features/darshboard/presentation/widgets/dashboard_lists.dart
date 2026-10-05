import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../../domain/entities/dashboard_summary.dart';
import 'dashboard_card.dart';

(Color, Color) _bandColors(ExpiryBand band) => switch (band) {
      ExpiryBand.expired || ExpiryBand.within30 => (AppColors.dangerFg, AppColors.dangerBg),
      ExpiryBand.within60 => (AppColors.warningFg, AppColors.warningBg),
      ExpiryBand.within90 => (AppColors.infoFg, AppColors.infoBg),
    };

String _bandLabel(ExpiryBand band) => switch (band) {
      ExpiryBand.expired => AppStrings.bandExpired,
      ExpiryBand.within30 => AppStrings.band30,
      ExpiryBand.within60 => AppStrings.band60,
      ExpiryBand.within90 => AppStrings.band90,
    };

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceLg),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class LowStockCard extends StatelessWidget {
  const LowStockCard({super.key, required this.alerts});

  final List<StockAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardCard(
      title: AppStrings.lowStockTitle,
      child: alerts.isEmpty
          ? const _EmptyNote(AppStrings.noLowStock)
          : Column(
              children: [
                for (final (index, alert) in alerts.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        StatusPill(
                          label: alert.isOutOfStock
                              ? AppStrings.stockOut
                              : AppStrings.stockOfThreshold(alert.sellableStock, alert.lowStockThreshold),
                          foreground: alert.isOutOfStock ? AppColors.dangerFg : AppColors.warningFg,
                          background: alert.isOutOfStock ? AppColors.dangerBg : AppColors.warningBg,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class ExpiryWatchCard extends StatelessWidget {
  const ExpiryWatchCard({super.key, required this.summary, required this.now});

  static const int _maxRows = 6;

  final DashboardSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = summary.expiring.where((alert) => alert.band(now) != null).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return DashboardCard(
      title: AppStrings.expiryWatch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final band in ExpiryBand.values)
                Expanded(child: _BandCount(band: band, count: summary.expiringCount(band, now))),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          const Divider(height: 1),
          if (rows.isEmpty)
            const _EmptyNote(AppStrings.noExpiring)
          else
            for (final alert in rows.take(_maxRows))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                          Text(
                            AppStrings.batchQuantity(alert.batchNumber, alert.quantity),
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Builder(builder: (context) {
                      final band = alert.band(now)!;
                      final (fg, bg) = _bandColors(band);
                      return StatusPill(
                        label: band == ExpiryBand.expired
                            ? AppStrings.bandExpired
                            : '${AppStrings.expiryPrefix} ${AppDates.short(alert.expiryDate)}',
                        foreground: fg,
                        background: bg,
                      );
                    }),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BandCount extends StatelessWidget {
  const _BandCount({required this.band, required this.count});

  final ExpiryBand band;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fg, bg) = _bandColors(band);
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.spaceSm),
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppDimens.radiusSm)),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: Column(
            children: [
              Text('$count', style: theme.textTheme.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w800)),
              Text(
                _bandLabel(band),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopSellersCard extends StatelessWidget {
  const TopSellersCard({super.key, required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardCard(
      title: AppStrings.topSellers,
      child: Column(
        children: [
          for (final (index, product) in products.indexed) ...[
            if (index > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(color: AppColors.neutralBg, shape: BoxShape.circle),
                    child: SizedBox(
                      width: AppDimens.rankBadgeSize,
                      height: AppDimens.rankBadgeSize,
                      child: Center(
                        child: Text('${index + 1}', style: theme.textTheme.labelMedium),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          AppStrings.unitsSold(product.unitsSold),
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Money.format(product.revenueMinor),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
