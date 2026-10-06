import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/stock_batch.dart';
import '../bloc/stock_cubit.dart';
import '../stock_constants.dart';

/// Adjust or write off one batch. Stays open and shows the message if the
/// change is rejected.
class AdjustStockDialog extends StatefulWidget {
  const AdjustStockDialog({super.key, required this.batch, required this.asOf});

  final StockBatch batch;
  final DateTime asOf;

  static Future<void> show(BuildContext context, {required StockBatch batch, required DateTime asOf}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdjustStockDialog(batch: batch, asOf: asOf),
    );
  }

  @override
  State<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<AdjustStockDialog> {
  late final bool _expired = widget.batch.expiryAt(widget.asOf) == BatchExpiry.expired;
  late StockAdjustmentReason _reason =
      _expired ? StockAdjustmentReason.expired : StockAdjustmentReason.damaged;
  late final TextEditingController _quantity =
      TextEditingController(text: _expired ? '0' : '${widget.batch.quantityOnHand}');
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = StockAdjustmentDraft(
      batchId: widget.batch.id,
      previousQuantity: widget.batch.quantityOnHand,
      newQuantity: int.tryParse(_quantity.text.trim()) ?? -1,
      reason: _reason,
      note: _note.text,
    );

    final error = await context.read<StockCubit>().adjust(draft);
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
    final batch = widget.batch;

    return AlertDialog(
      title: const Text(StockStrings.adjustTitle),
      content: SizedBox(
        width: StockLayout.dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                StockStrings.batchHeading(batch.medicineName, batch.batchNumber),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                StockStrings.currentQuantity(batch.quantityOnHand),
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              if (_expired)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                  child: Text(
                    StockStrings.writeOffHint,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.dangerFg),
                  ),
                ),
              const SizedBox(height: AppDimens.spaceLg),
              DropdownButtonFormField<StockAdjustmentReason>(
                value: _reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: StockStrings.fieldReason),
                items: [
                  for (final reason in StockAdjustmentReason.values)
                    DropdownMenuItem(value: reason, child: Text(StockStrings.reasonLabel(reason))),
                ],
                onChanged: _saving
                    ? null
                    : (reason) {
                        if (reason != null) setState(() => _reason = reason);
                      },
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _quantity,
                enabled: !_saving,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: StockStrings.fieldNewQuantity),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _note,
                enabled: !_saving,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: StockStrings.fieldNote),
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
          child: const Text(StockStrings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? StockStrings.saving : StockStrings.save),
        ),
      ],
    );
  }
}
