import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../returns/presentation/pages/sales_return_view.dart';
import '../widgets/shortcut_legend.dart';
import 'checkout_page.dart';

enum PosTab { newSale, salesReturn }

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  PosTab _tab = PosTab.newSale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _TabButton(
                icon: Icons.shopping_cart_outlined,
                label: AppStrings.tabNewSale,
                selected: _tab == PosTab.newSale,
                onTap: () => setState(() => _tab = PosTab.newSale),
              ),
              const SizedBox(width: AppDimens.spaceXl),
              _TabButton(
                icon: Icons.undo,
                label: AppStrings.tabSalesReturn,
                selected: _tab == PosTab.salesReturn,
                onTap: () => setState(() => _tab = PosTab.salesReturn),
              ),
              const Spacer(),
              if (_tab == PosTab.newSale) const ShortcutLegend(),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: AppDimens.spaceLg),
          Expanded(
            child: _tab == PosTab.newSale ? const CheckoutPage() : const SalesReturnView(),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: AppDimens.tabUnderlineHeight,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
