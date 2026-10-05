import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../bloc/purchase_form_cubit.dart';
import '../purchases_constants.dart';

/// One received batch: batch number, expiry, quantity, cost and selling price.
/// Text controllers live here so typing is never reset by a rebuild.
class PurchaseLineCard extends StatefulWidget {
  const PurchaseLineCard({super.key, required this.line, required this.enabled});

  final DraftLine line;
  final bool enabled;

  @override
  State<PurchaseLineCard> createState() => _PurchaseLineCardState();
}

class _PurchaseLineCardState extends State<PurchaseLineCard> {
  late final TextEditingController _batch = TextEditingController(text: widget.line.batchNumber);
  late final TextEditingController _quantity = TextEditingController(text: '${widget.line.quantity}');
  late final TextEditingController _cost = TextEditingController(
    text: widget.line.unitCostMinor > 0 ? Money.formatPlain(widget.line.unitCostMinor) : '',
  );
  late final TextEditingController _price =
      TextEditingController(text: Money.formatPlain(widget.line.sellingPriceMinor));

  static final List<TextInputFormatter> _moneyFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  ];

  @override
  void dispose() {
    _batch.dispose();
    _quantity.dispose();
    _cost.dispose();
    _price.dispose();
    super.dispose();
  }

  void _update(DraftLine Function(DraftLine line) change) {
    context.read<PurchaseFormCubit>().updateLine(widget.line.id, change);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = widget.line.expiryDate;
    final initial = current != null && !current.isBefore(today)
        ? current
        : today.add(const Duration(days: PurchasesLayout.defaultShelfLifeDays));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: PurchasesLayout.maxShelfLifeDays)),
    );
    if (picked != null && mounted) _update((line) => line.copyWith(expiryDate: picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = widget.line;
    final expiry = line.expiryDate;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        line.product.genericName,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.format(line.lineTotalMinor),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  tooltip: PurchasesStrings.removeLine,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.enabled
                      ? () => context.read<PurchaseFormCubit>().removeLine(line.id)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Wrap(
              spacing: AppDimens.spaceMd,
              runSpacing: AppDimens.spaceMd,
              children: [
                SizedBox(
                  width: PurchasesLayout.batchFieldWidth,
                  child: TextField(
                    controller: _batch,
                    enabled: widget.enabled,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: PurchasesStrings.batchNumber),
                    onChanged: (value) => _update((l) => l.copyWith(batchNumber: value.trim())),
                  ),
                ),
                SizedBox(
                  width: PurchasesLayout.expiryFieldWidth,
                  child: InkWell(
                    onTap: widget.enabled ? _pickExpiry : null,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: PurchasesStrings.expiryDate,
                        suffixIcon: Icon(Icons.calendar_today_outlined, size: AppDimens.iconSm),
                      ),
                      child: Text(expiry == null ? PurchasesStrings.selectDate : AppDates.short(expiry)),
                    ),
                  ),
                ),
                SizedBox(
                  width: PurchasesLayout.quantityFieldWidth,
                  child: TextField(
                    controller: _quantity,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: PurchasesStrings.quantity),
                    onChanged: (value) => _update((l) => l.copyWith(quantity: int.tryParse(value) ?? 0)),
                  ),
                ),
                SizedBox(
                  width: PurchasesLayout.moneyFieldWidth,
                  child: TextField(
                    controller: _cost,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _moneyFormatters,
                    decoration: InputDecoration(
                      labelText: PurchasesStrings.unitCost,
                      prefixText: '${AppConfig.currencyCode} ',
                    ),
                    onChanged: (value) =>
                        _update((l) => l.copyWith(unitCostMinor: Money.parseMinor(value) ?? 0)),
                  ),
                ),
                SizedBox(
                  width: PurchasesLayout.moneyFieldWidth,
                  child: TextField(
                    controller: _price,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _moneyFormatters,
                    decoration: InputDecoration(
                      labelText: PurchasesStrings.sellingPrice,
                      prefixText: '${AppConfig.currencyCode} ',
                    ),
                    onChanged: (value) =>
                        _update((l) => l.copyWith(sellingPriceMinor: Money.parseMinor(value) ?? 0)),
                  ),
                ),
              ],
            ),
            if (line.sellsBelowCost)
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                child: Text(
                  PurchasesStrings.sellingBelowCost,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warningFg),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
