import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/medicine.dart';
import '../bloc/medicines_cubit.dart';
import '../medicines_constants.dart';

/// Add or edit a medicine. Stays open and shows the message if saving fails
/// (for example a duplicate SKU).
class MedicineFormDialog extends StatefulWidget {
  const MedicineFormDialog({super.key, this.existing});

  final Medicine? existing;

  static Future<void> show(BuildContext context, {Medicine? existing}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicineFormDialog(existing: existing),
    );
  }

  @override
  State<MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<MedicineFormDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _generic = TextEditingController(text: widget.existing?.genericName ?? '');
  late final TextEditingController _sku = TextEditingController(text: widget.existing?.sku ?? '');
  late final TextEditingController _barcode = TextEditingController(text: widget.existing?.barcode ?? '');
  late final TextEditingController _price = TextEditingController(
    text: widget.existing == null ? '' : Money.formatPlain(widget.existing!.sellingPriceMinor),
  );
  late final TextEditingController _reorder = TextEditingController(
    text: '${widget.existing?.reorderLevel ?? MedicinesLayout.defaultReorderLevel}',
  );
  late DosageForm _form = widget.existing?.dosageForm ?? DosageForm.tablet;
  late bool _requiresPrescription = widget.existing?.requiresPrescription ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _generic.dispose();
    _sku.dispose();
    _barcode.dispose();
    _price.dispose();
    _reorder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = MedicineDraft(
      name: _name.text,
      genericName: _generic.text,
      dosageForm: _form,
      sku: _sku.text,
      barcode: _barcode.text,
      sellingPriceMinor: Money.parseMinor(_price.text) ?? 0,
      reorderLevel: int.tryParse(_reorder.text.trim()) ?? -1,
      requiresPrescription: _requiresPrescription,
    );

    final error = await context.read<MedicinesCubit>().save(draft, id: widget.existing?.id);
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
      title: Text(editing ? MedicinesStrings.editMedicine : MedicinesStrings.addMedicine),
      content: SizedBox(
        width: MedicinesLayout.formDialogWidth,
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
                decoration: const InputDecoration(labelText: MedicinesStrings.fieldName),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _generic,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: MedicinesStrings.fieldGeneric),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Wrap(
                spacing: AppDimens.spaceMd,
                runSpacing: AppDimens.spaceMd,
                children: [
                  SizedBox(
                    width: MedicinesLayout.halfFieldWidth,
                    child: DropdownButtonFormField<DosageForm>(
                      value: _form,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: MedicinesStrings.fieldForm),
                      items: [
                        for (final form in DosageForm.values)
                          DropdownMenuItem(value: form, child: Text(MedicinesStrings.formLabel(form))),
                      ],
                      onChanged: _saving
                          ? null
                          : (form) {
                              if (form != null) setState(() => _form = form);
                            },
                    ),
                  ),
                  SizedBox(
                    width: MedicinesLayout.halfFieldWidth,
                    child: TextField(
                      controller: _sku,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: MedicinesStrings.fieldSku),
                    ),
                  ),
                  SizedBox(
                    width: MedicinesLayout.halfFieldWidth,
                    child: TextField(
                      controller: _barcode,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: MedicinesStrings.fieldBarcode,
                        prefixIcon: Icon(Icons.qr_code_scanner),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MedicinesLayout.halfFieldWidth,
                    child: TextField(
                      controller: _price,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: InputDecoration(
                        labelText: MedicinesStrings.fieldPrice,
                        prefixText: '${AppConfig.currencyCode} ',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MedicinesLayout.halfFieldWidth,
                    child: TextField(
                      controller: _reorder,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: MedicinesStrings.fieldReorder),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(MedicinesStrings.fieldRx),
                subtitle: const Text(MedicinesStrings.fieldRxHint),
                value: _requiresPrescription,
                onChanged: _saving ? null : (value) => setState(() => _requiresPrescription = value),
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
                    MedicinesStrings.stockNote,
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
          child: const Text(MedicinesStrings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? MedicinesStrings.saving : MedicinesStrings.save),
        ),
      ],
    );
  }
}
