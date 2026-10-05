import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';

/// Pops with the discount in minor units (0 removes it), or null if cancelled.
class DiscountDialog extends StatefulWidget {
  const DiscountDialog({super.key, required this.subtotalMinor, required this.currentMinor});

  final int subtotalMinor;
  final int currentMinor;

  static Future<int?> show(
    BuildContext context, {
    required int subtotalMinor,
    required int currentMinor,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => DiscountDialog(subtotalMinor: subtotalMinor, currentMinor: currentMinor),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentMinor > 0 ? Money.formatPlain(widget.currentMinor) : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop(0);
      return;
    }

    final amount = Money.parseMinor(text);
    if (amount == null) {
      setState(() => _error = AppStrings.errorInvalidAmount);
      return;
    }
    if (amount > widget.subtotalMinor) {
      setState(() => _error = AppStrings.errorInvalidDiscount);
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.discountTitle),
      content: SizedBox(
        width: AppDimens.compactDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(
                labelText: AppStrings.discount,
                prefixText: '${AppConfig.currencyCode} ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              AppStrings.discountHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(AppStrings.cancel)),
        FilledButton(onPressed: _apply, child: const Text(AppStrings.apply)),
      ],
    );
  }
}
