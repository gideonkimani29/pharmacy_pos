import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../../domain/entities/stock_batch.dart';
import '../stock_constants.dart';

/// Rounded white card that holds a table.
class StockTableCard extends StatelessWidget {
  const StockTableCard({super.key, required this.header, required this.body});

  final Widget header;
  final Widget body;

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
          header,
          const Divider(height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class StockHeaderRow extends StatelessWidget {
  const StockHeaderRow({super.key, required this.children});

  final List<Widget> children;

  static TextStyle? style(BuildContext context) => Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
      child: Row(children: children),
    );
  }
}

/// Colour-coded expiry pill. Returns nothing for batches more than 90 days out.
class BatchExpiryPill extends StatelessWidget {
  const BatchExpiryPill({super.key, required this.expiry});

  final BatchExpiry expiry;

  @override
  Widget build(BuildContext context) {
    final (Color, Color, String)? style = switch (expiry) {
      BatchExpiry.expired => (AppColors.dangerFg, AppColors.dangerBg, StockStrings.expiredPill),
      BatchExpiry.within30 => (AppColors.dangerFg, AppColors.dangerBg, StockStrings.filter30),
      BatchExpiry.within60 => (AppColors.warningFg, AppColors.warningBg, StockStrings.filter60),
      BatchExpiry.within90 => (AppColors.infoFg, AppColors.infoBg, StockStrings.filter90),
      BatchExpiry.ok => null,
    };
    if (style == null) return const SizedBox.shrink();
    return StatusPill(label: style.$3, foreground: style.$1, background: style.$2);
  }
}

class StockMessage extends StatelessWidget {
  const StockMessage({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

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
