import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../bloc/dashboard_cubit.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/dashboard_lists.dart';
import '../widgets/kpi_card.dart';
import '../widgets/sales_bar_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // The shell builds this page each time the sidebar item is opened,
    // so the numbers refresh on every visit.
    context.read<DashboardCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: AppDimens.spaceLg),
          Expanded(
            child: BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                final summary = state.summary;
                if (summary == null) {
                  if (state.status == DashboardStatus.failure) {
                    return _LoadFailed(message: state.failure?.message);
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.status == DashboardStatus.loading)
                      const LinearProgressIndicator()
                    else if (state.status == DashboardStatus.failure)
                      const _StaleBanner(),
                    Expanded(child: _Content(summary: summary)),
                  ],
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.navDashboard,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                AppStrings.dashboardSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) => OutlinedButton.icon(
            onPressed: state.status == DashboardStatus.loading
                ? null
                : () => context.read<DashboardCubit>().load(),
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.refresh),
          ),
        ),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        AppStrings.dashboardStale,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.warningFg),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: AppDimens.emptyStateIconSize, color: AppColors.textSecondary),
          const SizedBox(height: AppDimens.spaceMd),
          Text(AppStrings.dashboardLoadFailed, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(message!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          OutlinedButton(
            onPressed: () => context.read<DashboardCubit>().load(),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.summary});

  static const double _gap = AppDimens.spaceLg;
  static const int _wideColumns = 4;
  static const int _mediumColumns = 2;
  static const int _leftFlex = 3;
  static const int _rightFlex = 2;

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= AppDimens.dashboardWideBreakpoint;
        final columns = wide
            ? _wideColumns
            : width >= AppDimens.dashboardMediumBreakpoint
                ? _mediumColumns
                : 1;
        final kpiWidth = ((width - _gap * (columns - 1)) / columns).floorToDouble();

        final kpis = [
          KpiCard(
            icon: Icons.payments_outlined,
            label: AppStrings.kpiTodaySales,
            value: Money.format(summary.todaySalesMinor),
            caption: AppStrings.kpiAverageSale(Money.format(summary.averageSaleMinor)),
            foreground: AppColors.successFg,
            background: AppColors.successBg,
          ),
          KpiCard(
            icon: Icons.receipt_long_outlined,
            label: AppStrings.kpiTransactions,
            value: '${summary.todayTransactions}',
            foreground: AppColors.infoFg,
            background: AppColors.infoBg,
          ),
          KpiCard(
            icon: Icons.medication_outlined,
            label: AppStrings.kpiItemsSold,
            value: '${summary.todayItemsSold}',
            foreground: AppColors.rxFg,
            background: AppColors.rxBg,
          ),
          KpiCard(
            icon: Icons.account_balance_wallet_outlined,
            label: AppStrings.kpiOnCredit,
            value: Money.format(summary.creditOutstandingMinor),
            foreground: AppColors.warningFg,
            background: AppColors.warningBg,
          ),
        ];

        Widget twoColumn(Widget left, Widget right) {
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: _gap), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: _leftFlex, child: left),
              const SizedBox(width: _gap),
              Expanded(flex: _rightFlex, child: right),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [for (final kpi in kpis) SizedBox(width: kpiWidth, child: kpi)],
              ),
              const SizedBox(height: _gap),
              twoColumn(
                DashboardCard(
                  title: AppStrings.salesLast7Days,
                  child: SalesBarChart(days: summary.weeklySales),
                ),
                ExpiryWatchCard(summary: summary, now: now),
              ),
              const SizedBox(height: _gap),
              twoColumn(
                LowStockCard(alerts: summary.lowStock),
                TopSellersCard(products: summary.topProducts),
              ),
            ],
          ),
        );
      },
    );
  }
}
