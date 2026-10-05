import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/payment.dart';
import 'payment_method_label.dart';

/// Collects one or more payments (split tender) until the total is covered.
/// Pops with the list of [PaymentLine]s, or null if cancelled.
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({super.key, required this.totalMinor});

  final int totalMinor;

  static Future<List<PaymentLine>?> show(BuildContext context, {required int totalMinor}) {
    return showDialog<List<PaymentLine>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(totalMinor: totalMinor),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final List<PaymentLine> _lines = [];
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  PaymentMethod _method = PaymentMethod.cash;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillAmount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  int get _paid => _lines.fold(0, (sum, line) => sum + line.amountMinor);
  int get _nonCashPaid => _lines.where((l) => !l.method.isCash).fold(0, (sum, l) => sum + l.amountMinor);
  int get _remaining => widget.totalMinor > _paid ? widget.totalMinor - _paid : 0;
  int get _change => _paid > widget.totalMinor ? _paid - widget.totalMinor : 0;
  bool get _isCovered => _paid >= widget.totalMinor;

  void _prefillAmount() {
    _amountController.text = _remaining > 0 ? Money.formatPlain(_remaining) : '';
    _amountController.selection = TextSelection(baseOffset: 0, extentOffset: _amountController.text.length);
  }

  void _selectMethod(PaymentMethod method) {
    setState(() {
      _method = method;
      _error = null;
      _referenceController.clear();
    });
    _prefillAmount();
    _amountFocus.requestFocus();
  }

  void _setAmount(int minor) {
    _amountController.text = Money.formatPlain(minor);
    _amountController.selection = TextSelection.collapsed(offset: _amountController.text.length);
  }

  void _addPayment() {
    final amount = Money.parseMinor(_amountController.text);
    if (_remaining == 0) return _fail(AppStrings.errorNothingRemaining);
    if (amount == null || amount <= 0) return _fail(AppStrings.errorInvalidAmount);

    if (!_method.isCash && amount > _remaining) {
      return _fail(AppStrings.errorAmountExceedsRemaining);
    }

    String? reference;
    if (_method.needsReference) {
      reference = _referenceController.text.trim();
      if (reference.length < AppConfig.minPaymentReferenceLength) {
        return _fail(AppStrings.errorReferenceShort(AppConfig.minPaymentReferenceLength));
      }
    }

    setState(() {
      _lines.add(PaymentLine(method: _method, amountMinor: amount, reference: reference));
      _error = null;
      _referenceController.clear();
    });
    _prefillAmount();
  }

  void _fail(String message) => setState(() => _error = message);

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      _error = null;
    });
    _prefillAmount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text(AppStrings.paymentTitle),
      content: SizedBox(
        width: AppDimens.dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AmountDue(totalMinor: widget.totalMinor),
              const SizedBox(height: AppDimens.spaceLg),
              SegmentedButton<PaymentMethod>(
                showSelectedIcon: false,
                segments: [
                  for (final method in PaymentMethod.values)
                    ButtonSegment(value: method, label: Text(method.label), icon: Icon(method.icon)),
                ],
                selected: {_method},
                onSelectionChanged: (selection) => _selectMethod(selection.first),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              TextField(
                controller: _amountController,
                focusNode: _amountFocus,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addPayment(),
                decoration: InputDecoration(
                  labelText: AppStrings.amountLabel,
                  prefixText: '${AppConfig.currencyCode} ',
                ),
              ),
              if (_method.isCash) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: [
                    ActionChip(
                      label: const Text(AppStrings.exactAmount),
                      onPressed: _remaining > 0 ? () => _setAmount(_remaining) : null,
                    ),
                    for (final denomination in AppConfig.quickCashMinor)
                      ActionChip(
                        label: Text(Money.formatPlain(denomination, grouped: true).replaceAll('.00', '')),
                        onPressed: () => _setAmount(denomination),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: _referenceController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addPayment(),
                  decoration: InputDecoration(labelText: _method.referenceLabel),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.dangerFg)),
              ],
              const SizedBox(height: AppDimens.spaceMd),
              OutlinedButton.icon(
                onPressed: _remaining > 0 ? _addPayment : null,
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.addPayment),
              ),
              if (_lines.isNotEmpty) ...[
                const Divider(height: AppDimens.spaceXl),
                Text(AppStrings.paymentsAdded, style: theme.textTheme.titleSmall),
                for (var i = 0; i < _lines.length; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_lines[i].method.icon),
                    title: Text(Money.format(_lines[i].amountMinor)),
                    subtitle: _lines[i].reference == null ? null : Text(_lines[i].reference!),
                    trailing: IconButton(
                      tooltip: AppStrings.removePayment,
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeLine(i),
                    ),
                  ),
              ],
              const Divider(height: AppDimens.spaceXl),
              _SummaryRow(label: AppStrings.paid, value: Money.format(_paid)),
              _SummaryRow(
                label: AppStrings.remaining,
                value: Money.format(_remaining),
                emphasised: _remaining > 0,
              ),
              if (_change > 0)
                _SummaryRow(
                  label: AppStrings.changeDue,
                  value: Money.format(_change),
                  emphasised: true,
                  color: AppColors.successFg,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _isCovered && _nonCashPaid <= widget.totalMinor
              ? () => Navigator.of(context).pop(List<PaymentLine>.unmodifiable(_lines))
              : null,
          child: const Text(AppStrings.completeSale),
        ),
      ],
    );
  }
}

class _AmountDue extends StatelessWidget {
  const _AmountDue({required this.totalMinor});

  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppStrings.amountDue, style: theme.textTheme.titleMedium),
            Text(
              Money.format(totalMinor),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasised = false, this.color});

  final String label;
  final String value;
  final bool emphasised;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: emphasised ? FontWeight.w700 : FontWeight.w400,
          color: color,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
