import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

class ShortcutLegend extends StatelessWidget {
  const ShortcutLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Hint(keyLabel: AppStrings.shortcutSearchKey, description: AppStrings.shortcutSearchLabel),
        SizedBox(width: AppDimens.spaceLg),
        _Hint(keyLabel: AppStrings.shortcutPayKey, description: AppStrings.shortcutPayLabel),
        SizedBox(width: AppDimens.spaceLg),
        _Hint(keyLabel: AppStrings.shortcutClearKey, description: AppStrings.shortcutClearLabel),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.keyLabel, required this.description});

  final String keyLabel;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.neutralBg,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.pillVerticalPadding,
            ),
            child: Text(
              keyLabel,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(description, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
