import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/customer_account.dart';
import '../bloc/customer_accounts_cubit.dart';
import '../customers_constants.dart';

/// Add or edit a customer. Stays open and shows the message if saving fails
/// (for example a phone number that is already registered).
class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({super.key, this.existing});

  final CustomerAccount? existing;

  static Future<void> show(BuildContext context, {CustomerAccount? existing}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerFormDialog(existing: existing),
    );
  }

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.existing?.email ?? '');
  late final TextEditingController _limit = TextEditingController(
    text: widget.existing == null ? '0' : Money.formatPlain(widget.existing!.creditLimitMinor),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = CustomerDraft(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      creditLimitMinor: Money.parseMinor(_limit.text) ?? -1,
    );

    final error = await context.read<CustomerAccountsCubit>().save(draft, id: widget.existing?.id);
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
    final editing = widget.existing != null;

    return AlertDialog(
      title: Text(editing ? CustomersStrings.editCustomer : CustomersStrings.addCustomer),
      content: SizedBox(
        width: CustomersLayout.formDialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                enabled: !_saving,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: CustomersStrings.fieldName),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
                decoration: const InputDecoration(
                  labelText: CustomersStrings.fieldPhone,
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: CustomersStrings.fieldEmail,
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _limit,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: CustomersStrings.fieldLimit,
                  prefixText: '${AppConfig.currencyCode} ',
                  helperText: CustomersStrings.limitHint,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                  child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.dangerFg)),
                ),
              if (editing)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                  child: Text(
                    CustomersStrings.balanceNote,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
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
          child: Text(_saving ? CustomersStrings.saving : CustomersStrings.save),
        ),
      ],
    );
  }
}
