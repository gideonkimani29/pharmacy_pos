import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

enum AppModule {
  dashboard(AppStrings.navDashboard, Icons.dashboard_outlined),
  sales(AppStrings.navSales, Icons.point_of_sale),
  purchases(AppStrings.navPurchases, Icons.shopping_cart_outlined),
  medicines(AppStrings.navMedicines, Icons.medication_outlined),
  stock(AppStrings.navStock, Icons.inventory_2_outlined),
  customers(AppStrings.navCustomers, Icons.people_outline),
  reports(AppStrings.navReports, Icons.bar_chart_outlined),
  settings(AppStrings.navSettings, Icons.settings_outlined);

  const AppModule(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.compact,
  });

  final AppModule selected;
  final ValueChanged<AppModule> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? AppDimens.sidebarCompactWidth : AppDimens.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _Brand(compact: compact),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              children: [
                for (final module in AppModule.values)
                  _NavItem(
                    module: module,
                    selected: module == selected,
                    compact: compact,
                    onTap: () => onSelected(module),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppDimens.brandHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_pharmacy, color: AppColors.primary),
          if (!compact) ...[
            const SizedBox(width: AppDimens.spaceMd),
            Text(
              AppStrings.appTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.module,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AppModule module;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onPrimary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: Tooltip(
        message: compact ? module.label : '',
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: AppDimens.navItemHeight,
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  if (!compact) const SizedBox(width: AppDimens.spaceLg),
                  Icon(module.icon, color: foreground),
                  if (!compact) ...[
                    const SizedBox(width: AppDimens.spaceLg),
                    Flexible(
                      child: Text(
                        module.label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: foreground,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
