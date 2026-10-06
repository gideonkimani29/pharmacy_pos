import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../bloc/stock_cubit.dart';
import '../stock_constants.dart';
import '../widgets/batch_table.dart';
import '../widgets/medicine_stock_table.dart';
import '../widgets/stock_toolbar.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  @override
  void initState() {
    super.initState();
    // The shell builds this page each time the sidebar item is opened,
    // so the batches refresh on every visit.
    context.read<StockCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<StockCubit, StockState>(
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
            Text(
              StockStrings.title,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              StockStrings.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const _Kpis(),
            const SizedBox(height: AppDimens.spaceLg),
            const StockToolbar(),
            const SizedBox(height: AppDimens.spaceLg),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < StockLayout.compactBreakpoint;
                  return BlocBuilder<StockCubit, StockState>(
                    buildWhen: (previous, current) => previous.view != current.view,
                    builder: (context, state) => state.view == StockView.batches
                        ? BatchTable(compact: compact)
                        : MedicineStockTable(compact: compact),
                  );
                },
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
    return BlocBuilder<StockCubit, StockState>(
      buildWhen: (previous, current) => previous.batches != current.batches || previous.asOf != current.asOf,
      builder: (context, state) {
        return Wrap(
          spacing: AppDimens.spaceLg,
          runSpacing: AppDimens.spaceLg,
          children: [
            SizedBox(
              width: StockLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.inventory_2_outlined,
                label: StockStrings.kpiSellable,
                value: '${state.sellableUnits}',
                foreground: AppColors.successFg,
                background: AppColors.successBg,
              ),
            ),
            SizedBox(
              width: StockLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.payments_outlined,
                label: StockStrings.kpiValue,
                value: Money.format(state.stockValueMinor),
                foreground: AppColors.infoFg,
                background: AppColors.infoBg,
              ),
            ),
            SizedBox(
              width: StockLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.hourglass_bottom,
                label: StockStrings.kpiExpiring,
                value: '${state.expiringBatchCount}',
                foreground: AppColors.warningFg,
                background: AppColors.warningBg,
              ),
            ),
            SizedBox(
              width: StockLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.delete_outline,
                label: StockStrings.kpiExpired,
                value: '${state.expiredUnits}',
                foreground: AppColors.dangerFg,
                background: AppColors.dangerBg,
              ),
            ),
          ],
        );
      },
    );
  }
}
