import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/reports_cubit.dart';
import '../reports_constants.dart';
import '../widgets/losses_report_view.dart';
import '../widgets/profit_report_view.dart';
import '../widgets/report_controls.dart';
import '../widgets/sales_report_view.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  void initState() {
    super.initState();
    // The shell builds this page each time the sidebar item is opened,
    // so the figures refresh on every visit.
    context.read<ReportsCubit>().load();
  }

  Future<void> _copyCsv() async {
    final cubit = context.read<ReportsCubit>();
    final csv = cubit.currentCsv();
    if (csv == null) {
      cubit.announce(ReportsStrings.nothingToCopy);
      return;
    }
    await Clipboard.setData(ClipboardData(text: csv));
    cubit.announce(ReportsStrings.csvCopied(cubit.currentReportName));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<ReportsCubit, ReportsState>(
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
                        ReportsStrings.title,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        ReportsStrings.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _copyCsv,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text(ReportsStrings.copyCsv),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const ReportControls(),
            const SizedBox(height: AppDimens.spaceLg),
            const Expanded(child: _ReportBody()),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        final sales = state.sales;
        final profit = state.profit;
        final losses = state.losses;

        if (sales == null || profit == null || losses == null) {
          if (state.status == ReportsStatus.failure) {
            return _LoadFailed(message: state.failure?.message);
          }
          return const Center(child: CircularProgressIndicator());
        }

        final report = switch (state.tab) {
          ReportTab.sales => SalesReportView(report: sales),
          ReportTab.profit => ProfitReportView(report: profit),
          ReportTab.losses => LossesReportView(report: losses),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.status == ReportsStatus.loading) const LinearProgressIndicator(),
            if (state.status == ReportsStatus.failure && state.failure != null)
              Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  state.failure!.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.warningFg),
                ),
              ),
            Expanded(child: SingleChildScrollView(child: report)),
          ],
        );
      },
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
          Text(ReportsStrings.loadFailed, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(message!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          OutlinedButton(
            onPressed: () => context.read<ReportsCubit>().load(),
            child: const Text(ReportsStrings.retry),
          ),
        ],
      ),
    );
  }
}
