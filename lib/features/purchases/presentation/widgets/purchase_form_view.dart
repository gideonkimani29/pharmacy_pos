import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/supplier.dart';
import '../bloc/purchase_form_cubit.dart';
import '../purchases_constants.dart';
import 'purchase_line_card.dart';
import 'purchase_product_search.dart';

/// "Record a purchase" form. Expects a [PurchaseFormCubit] above it.
class PurchaseFormView extends StatelessWidget {
  const PurchaseFormView({super.key, required this.onClose});

  /// Called when the cashier cancels or the purchase has been saved.
  final VoidCallback onClose;

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PurchaseFormCubit, PurchaseFormState>(
          listenWhen: (previous, current) => current.notice != null && previous.notice != current.notice,
          listener: (context, state) => _snack(context, state.notice!.message),
        ),
        BlocListener<PurchaseFormCubit, PurchaseFormState>(
          listenWhen: (previous, current) =>
              previous.status != current.status && current.status == PurchaseFormStatus.saved,
          listener: (context, state) {
            _snack(context, PurchasesStrings.savedMessage(state.savedPurchase!.reference));
            onClose();
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onClose: onClose),
          const SizedBox(height: AppDimens.spaceLg),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= PurchasesLayout.wideBreakpoint;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: SingleChildScrollView(child: _ItemsPane())),
                      const SizedBox(width: AppDimens.spaceLg),
                      SizedBox(
                        width: PurchasesLayout.detailsPaneWidth,
                        child: SingleChildScrollView(child: _DetailsPane(onClose: onClose)),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DetailsPane(onClose: onClose),
                      const SizedBox(height: AppDimens.spaceLg),
                      const _ItemsPane(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: PurchasesStrings.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: onClose,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          PurchasesStrings.formTitle,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(padding: const EdgeInsets.all(AppDimens.spaceLg), child: child),
    );
  }
}

class _ItemsPane extends StatelessWidget {
  const _ItemsPane();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PurchasesStrings.itemsReceived,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          const PurchaseProductSearch(),
          const SizedBox(height: AppDimens.spaceLg),
          BlocBuilder<PurchaseFormCubit, PurchaseFormState>(
            buildWhen: (previous, current) =>
                previous.lines != current.lines || previous.status != current.status,
            builder: (context, state) {
              if (state.lines.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXl),
                  child: Text(
                    PurchasesStrings.noLines,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                );
              }
              return Column(
                children: [
                  for (final line in state.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                      child: PurchaseLineCard(
                        key: ValueKey(line.id),
                        line: line,
                        enabled: !state.isSubmitting,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({required this.onClose});

  final VoidCallback onClose;

  Future<void> _pickDate(BuildContext context, PurchaseFormState state) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: state.receivedOn,
      firstDate: today.subtract(const Duration(days: PurchasesLayout.receivedLookbackDays)),
      lastDate: today,
    );
    if (picked != null && context.mounted) context.read<PurchaseFormCubit>().setReceivedOn(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<PurchaseFormCubit>();

    return _Card(
      child: BlocBuilder<PurchaseFormCubit, PurchaseFormState>(
        builder: (context, state) {
          final enabled = !state.isSubmitting;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<Supplier>(
                value: state.supplier,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: PurchasesStrings.supplier,
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                items: [
                  for (final supplier in state.suppliers)
                    DropdownMenuItem<Supplier>(value: supplier, child: Text(supplier.name)),
                ],
                onChanged: enabled
                    ? (supplier) {
                        if (supplier != null) cubit.setSupplier(supplier);
                      }
                    : null,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                enabled: enabled,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: PurchasesStrings.invoiceNumber,
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                onChanged: cubit.setInvoiceNumber,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              InkWell(
                onTap: enabled ? () => _pickDate(context, state) : null,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: PurchasesStrings.receivedOn,
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(AppDates.short(state.receivedOn)),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                PurchasesStrings.payment,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              SegmentedButton<PurchasePaymentStatus>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: PurchasePaymentStatus.paid, label: Text(PurchasesStrings.statusPaid)),
                  ButtonSegment(
                    value: PurchasePaymentStatus.onCredit,
                    label: Text(PurchasesStrings.statusOnCredit),
                  ),
                ],
                selected: {state.paymentStatus},
                onSelectionChanged: enabled ? (selection) => cubit.setPaymentStatus(selection.first) : null,
              ),
              const Divider(height: AppDimens.spaceXl),
              _SummaryRow(label: PurchasesStrings.summaryLines, value: '${state.lines.length}'),
              _SummaryRow(label: PurchasesStrings.summaryUnits, value: '${state.unitCount}'),
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(PurchasesStrings.summaryTotal, style: theme.textTheme.titleMedium),
                  Text(
                    Money.format(state.totalMinor),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
              SizedBox(
                height: AppDimens.payButtonHeight,
                child: FilledButton.icon(
                  onPressed: enabled ? cubit.submit : null,
                  icon: state.isSubmitting
                      ? const SizedBox(
                          width: AppDimens.iconSm,
                          height: AppDimens.iconSm,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  label: Text(state.isSubmitting ? PurchasesStrings.saving : PurchasesStrings.save),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              OutlinedButton(
                onPressed: enabled ? onClose : null,
                child: const Text(PurchasesStrings.cancel),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
