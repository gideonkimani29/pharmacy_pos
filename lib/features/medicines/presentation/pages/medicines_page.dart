import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../bloc/medicines_cubit.dart';
import '../medicines_constants.dart';
import '../widgets/medicine_form_dialog.dart';
import '../widgets/medicine_table.dart';
import '../widgets/medicine_toolbar.dart';

class MedicinesPage extends StatefulWidget {
  const MedicinesPage({super.key});

  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  @override
  void initState() {
    super.initState();
    // The shell builds this page each time the sidebar item is opened,
    // so the list refreshes on every visit.
    context.read<MedicinesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<MedicinesCubit, MedicinesState>(
      listenWhen: (previous, current) => current.notice != null && previous.notice != current.notice,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.notice!.message)));
      },
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
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
                        MedicinesStrings.title,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        MedicinesStrings.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => MedicineFormDialog.show(context),
                  icon: const Icon(Icons.add),
                  label: const Text(MedicinesStrings.addMedicine),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const _Kpis(),
            const SizedBox(height: AppDimens.spaceLg),
            const MedicineToolbar(),
            const SizedBox(height: AppDimens.spaceLg),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => MedicineTable(
                  compact: constraints.maxWidth < MedicinesLayout.compactBreakpoint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MedicinesCubit, MedicinesState>(
      buildWhen: (previous, current) => previous.medicines != current.medicines,
      builder: (context, state) {
        return Wrap(
          spacing: AppDimens.spaceLg,
          runSpacing: AppDimens.spaceLg,
          children: [
            SizedBox(
              width: MedicinesLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.medication_outlined,
                label: MedicinesStrings.kpiActive,
                value: '${state.activeCount}',
                foreground: AppColors.successFg,
                background: AppColors.successBg,
              ),
            ),
            SizedBox(
              width: MedicinesLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.trending_down,
                label: MedicinesStrings.kpiLow,
                value: '${state.count(MedicineFilter.lowStock)}',
                foreground: AppColors.warningFg,
                background: AppColors.warningBg,
              ),
            ),
            SizedBox(
              width: MedicinesLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.remove_shopping_cart_outlined,
                label: MedicinesStrings.kpiOut,
                value: '${state.count(MedicineFilter.outOfStock)}',
                foreground: AppColors.dangerFg,
                background: AppColors.dangerBg,
              ),
            ),
            SizedBox(
              width: MedicinesLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.assignment_outlined,
                label: MedicinesStrings.kpiRx,
                value: '${state.count(MedicineFilter.prescription)}',
                foreground: AppColors.rxFg,
                background: AppColors.rxBg,
              ),
            ),
          ],
        );
      },
    );
  }
}
