import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';

/// Section switcher: a side list on wide windows, chips on narrow ones.
class SettingsNav extends StatelessWidget {
  const SettingsNav({super.key, required this.compact});

  final bool compact;

  static String _label(SettingsSection section) => switch (section) {
        SettingsSection.pharmacy => SettingsStrings.navPharmacy,
        SettingsSection.sales => SettingsStrings.navSales,
        SettingsSection.receipts => SettingsStrings.navReceipts,
        SettingsSection.users => SettingsStrings.navUsers,
      };

  static IconData _icon(SettingsSection section) => switch (section) {
        SettingsSection.pharmacy => Icons.storefront_outlined,
        SettingsSection.sales => Icons.point_of_sale,
        SettingsSection.receipts => Icons.receipt_long_outlined,
        SettingsSection.users => Icons.manage_accounts_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) => previous.section != current.section,
      builder: (context, state) {
        if (compact) {
          return Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            children: [
              for (final section in SettingsSection.values)
                ChoiceChip(
                  avatar: Icon(_icon(section), size: AppDimens.iconSm),
                  label: Text(_label(section)),
                  selected: state.section == section,
                  onSelected: (_) => cubit.setSection(section),
                ),
            ],
          );
        }

        return SizedBox(
          width: SettingsLayout.navWidth,
          child: Column(
            children: [
              for (final section in SettingsSection.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
                  child: Material(
                    color: state.section == section ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        _icon(section),
                        color: state.section == section ? AppColors.onPrimary : AppColors.textSecondary,
                      ),
                      title: Text(
                        _label(section),
                        style: TextStyle(
                          color: state.section == section ? AppColors.onPrimary : AppColors.textPrimary,
                          fontWeight: state.section == section ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      onTap: () => cubit.setSection(section),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
