import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../checkout/presentation/widgets/product_badges.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../../domain/entities/medicine.dart';
import '../bloc/medicines_cubit.dart';
import '../medicines_constants.dart';
import 'medicine_form_dialog.dart';

class MedicineTable extends StatelessWidget {
  const MedicineTable({super.key, required this.compact});

  /// Hides the generic-name and reorder columns on narrow windows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          _HeaderRow(compact: compact),
          const Divider(height: 1),
          Expanded(child: _Body(compact: compact)),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
      child: Row(
        children: [
          Expanded(flex: MedicinesLayout.nameFlex, child: Text(MedicinesStrings.colMedicine, style: style)),
          if (!compact)
            Expanded(flex: MedicinesLayout.genericFlex, child: Text(MedicinesStrings.colGeneric, style: style)),
          Expanded(flex: MedicinesLayout.priceFlex, child: Text(MedicinesStrings.colPrice, style: style)),
          SizedBox(
            width: MedicinesLayout.stockColumnWidth,
            child: Center(child: Text(MedicinesStrings.colStock, style: style)),
          ),
          if (!compact)
            SizedBox(
              width: MedicinesLayout.reorderColumnWidth,
              child: Center(child: Text(MedicinesStrings.colReorder, style: style)),
            ),
          SizedBox(
            width: MedicinesLayout.activeColumnWidth,
            child: Center(child: Text(MedicinesStrings.colActive, style: style)),
          ),
          SizedBox(
            width: MedicinesLayout.editColumnWidth,
            child: Center(child: Text(MedicinesStrings.colEdit, style: style)),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MedicinesCubit, MedicinesState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.medicines != current.medicines ||
          previous.query != current.query ||
          previous.filter != current.filter,
      builder: (context, state) {
        final visible = state.visible;

        if (state.medicines.isEmpty) {
          if (state.status == MedicinesStatus.failure) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              title: MedicinesStrings.loadFailed,
              detail: state.failure?.message,
              actionLabel: MedicinesStrings.retry,
              onAction: () => context.read<MedicinesCubit>().load(),
            );
          }
          if (state.status == MedicinesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return const _Message(
            icon: Icons.medication_outlined,
            title: MedicinesStrings.emptyTitle,
            detail: MedicinesStrings.emptyHint,
          );
        }

        if (visible.isEmpty) {
          return _Message(
            icon: Icons.search_off_outlined,
            title: state.query.trim().isEmpty
                ? MedicinesStrings.noMatchesFilter
                : MedicinesStrings.noMatches(state.query.trim()),
          );
        }

        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _MedicineRow(
            key: ValueKey(visible[index].id),
            medicine: visible[index],
            compact: compact,
          ),
        );
      },
    );
  }
}

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({super.key, required this.medicine, required this.compact});

  final Medicine medicine;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<MedicinesCubit>();

    return Opacity(
      opacity: medicine.isActive ? 1 : MedicinesLayout.inactiveOpacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
        child: Row(
          children: [
            Expanded(
              flex: MedicinesLayout.nameFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          medicine.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (medicine.requiresPrescription) ...[
                        const SizedBox(width: AppDimens.spaceSm),
                        const RxBadge(),
                      ],
                    ],
                  ),
                  Text(
                    MedicinesStrings.detailLine(
                      medicine.sku,
                      medicine.barcode,
                      MedicinesStrings.formLabel(medicine.dosageForm),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!compact)
              Expanded(
                flex: MedicinesLayout.genericFlex,
                child: Text(medicine.genericName, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            Expanded(
              flex: MedicinesLayout.priceFlex,
              child: Text(
                Money.format(medicine.sellingPriceMinor),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: MedicinesLayout.stockColumnWidth,
              child: Center(child: _StockPill(medicine: medicine)),
            ),
            if (!compact)
              SizedBox(
                width: MedicinesLayout.reorderColumnWidth,
                child: Center(child: Text('${medicine.reorderLevel}')),
              ),
            SizedBox(
              width: MedicinesLayout.activeColumnWidth,
              child: Center(
                child: Tooltip(
                  message: MedicinesStrings.activeTooltip,
                  child: Switch(
                    value: medicine.isActive,
                    onChanged: (_) => cubit.toggleActive(medicine),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MedicinesLayout.editColumnWidth,
              child: Center(
                child: IconButton(
                  tooltip: MedicinesStrings.editTooltip,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => MedicineFormDialog.show(context, existing: medicine),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, String label) = switch (medicine.stockLevel) {
      StockLevel.out => (AppColors.dangerFg, AppColors.dangerBg, MedicinesStrings.stockOut),
      StockLevel.low => (AppColors.warningFg, AppColors.warningBg, '${medicine.stockOnHand}'),
      StockLevel.ok => (AppColors.successFg, AppColors.successBg, '${medicine.stockOnHand}'),
    };
    return StatusPill(label: label, foreground: fg, background: bg);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.detail, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.emptyStateIconSize, color: AppColors.textSecondary),
          const SizedBox(height: AppDimens.spaceMd),
          Text(title, style: theme.textTheme.titleMedium),
          if (detail != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(detail!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppDimens.spaceLg),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
