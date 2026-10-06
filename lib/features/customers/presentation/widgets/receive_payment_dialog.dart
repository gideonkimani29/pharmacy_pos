import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../checkout/domain/entities/payment.dart';
import '../../domain/customer_messages.dart';
import '../../domain/entities/customer_account.dart';
import '../bloc/customer_accounts_cubit.dart';
import '../customers_constants.dart';

/// Records a payment against a customer's balance (cash, card or mobile).
class ReceivePaymentDialog extends StatefulWidget {
  const ReceivePaymentDialog({super.key, required this.account});

  final CustomerAccount account;

  static Future<void> show(BuildContext context, {required CustomerAccount account}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceivePaymentDialog(account: account),
    );
  }

  @override
  State<ReceivePaymentDialog> createState() => _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState extends State<ReceivePaymentDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: Money.formatPlain(widget.account.balanceMinor));
  final TextEditingController _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  int get _enteredMinor => Money.parseMinor(_amount.text) ?? 0;

  Future<void> _save() async {
    final amount = _enteredMinor;
    if (amount > widget.account.balanceMinor) {
      setState(() => _error = CustomerMessages.paymentExceedsBalance);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = AccountPaymentDraft(
      customerId: widget.account.id,
      amountMinor: amount,
      method: _method,
      reference: _method.needsReference ? _reference.text.trim() : null,
    );

    final error = await context.read<CustomerAccountsCubit>().receivePayment(draft);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = widget.account;
    final remaining = account.balanceMinor - _enteredMinor;

    return AlertDialog(
      title: Text(CustomersStrings.paymentTitle(account.name)),
      content: SizedBox(
        width: CustomersLayout.paymentDialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                CustomersStrings.currentBalance(Money.format(account.balanceMinor)),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.dangerFg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              SegmentedButton<PaymentMethod>(
                showSelectedIcon: false,
                segments: [
                  for (final method in PaymentMethod.values)
                    ButtonSegment(value: method, label: Text(CustomersStrings.methodLabel(method))),
                ],
                selected: {_method},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                          _method = selection.first;
                          _error = null;
                          _reference.clear();
                        }),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              TextField(
                controller: _amount,
                enabled: !_saving,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: CustomersStrings.fieldAmount,
                  prefixText: '${AppConfig.currencyCode} ',
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  label: const Text(CustomersStrings.fullBalance),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _amount.text = Money.formatPlain(account.balanceMinor)),
                ),
              ),
              if (_method.needsReference) ...[
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: _reference,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: CustomersStrings.referenceLabel(_method)),
                  onSubmitted: (_) => _save(),
                ),
              ],
              if (_enteredMinor > 0 && remaining >= 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                  child: Text(
                    CustomersStrings.balanceAfter(Money.format(remaining)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                  child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.dangerFg)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(CustomersStrings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? CustomersStrings.saving : CustomersStrings.recordPayment),
        ),
      ],
    );
  }
}
