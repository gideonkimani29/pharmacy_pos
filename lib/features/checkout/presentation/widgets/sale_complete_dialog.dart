import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sale.dart';

class SaleCompleteDialog extends StatelessWidget {
  const SaleCompleteDialog({super.key, required this.receipt});

  static const double _iconSize = 48;

  final SaleReceipt receipt;

  static Future<void> show(BuildContext context, SaleReceipt receipt) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaleCompleteDialog(receipt: receipt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.check_circle, size: _iconSize, color: AppColors.successFg),
      title: const Text(AppStrings.saleComplete),
      content: SizedBox(
        width: AppDimens.compactDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(theme, AppStrings.receiptNumber, receipt.receiptNumber),
            _row(theme, AppStrings.total, Money.format(receipt.totalMinor)),
            if (receipt.changeDueMinor > 0)
              _row(theme, AppStrings.changeDue, Money.format(receipt.changeDueMinor), highlight: true),
            if (receipt.amountOnAccountMinor > 0)
              _row(theme, AppStrings.onAccount, Money.format(receipt.amountOnAccountMinor), highlight: true),
          ],
        ),
      ),
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.newSale),
        ),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value, {bool highlight = false}) {
    final style = highlight
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.successFg)
        : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
