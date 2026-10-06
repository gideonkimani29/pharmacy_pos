import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../dashboard/presentation/widgets/kpi_card.dart';
import '../bloc/customer_accounts_cubit.dart';
import '../customers_constants.dart';
import '../widgets/customer_form_dialog.dart';
import '../widgets/customer_table.dart';
import '../widgets/customer_toolbar.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  @override
  void initState() {
    super.initState();
    // The shell builds this page each time the sidebar item is opened,
    // so the list refreshes on every visit.
    context.read<CustomerAccountsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<CustomerAccountsCubit, CustomerAccountsState>(
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
                        CustomersStrings.title,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        CustomersStrings.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => CustomerFormDialog.show(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text(CustomersStrings.addCustomer),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const _Kpis(),
            const SizedBox(height: AppDimens.spaceLg),
            const CustomerToolbar(),
            const SizedBox(height: AppDimens.spaceLg),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => CustomerTable(
                  compact: constraints.maxWidth < CustomersLayout.compactBreakpoint,
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
    return BlocBuilder<CustomerAccountsCubit, CustomerAccountsState>(
      buildWhen: (previous, current) => previous.accounts != current.accounts,
      builder: (context, state) {
        return Wrap(
          spacing: AppDimens.spaceLg,
          runSpacing: AppDimens.spaceLg,
          children: [
            SizedBox(
              width: CustomersLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.people_outline,
                label: CustomersStrings.kpiActive,
                value: '${state.activeCount}',
                foreground: AppColors.successFg,
                background: AppColors.successBg,
              ),
            ),
            SizedBox(
              width: CustomersLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.account_balance_wallet_outlined,
                label: CustomersStrings.kpiOwed,
                value: Money.format(state.outstandingMinor),
                foreground: AppColors.warningFg,
                background: AppColors.warningBg,
              ),
            ),
            SizedBox(
              width: CustomersLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.hourglass_bottom,
                label: CustomersStrings.kpiOwing,
                value: '${state.count(CustomerFilter.owing)}',
                foreground: AppColors.infoFg,
                background: AppColors.infoBg,
              ),
            ),
            SizedBox(
              width: CustomersLayout.kpiWidth,
              child: KpiCard(
                icon: Icons.warning_amber_outlined,
                label: CustomersStrings.kpiOverLimit,
                value: '${state.count(CustomerFilter.overLimit)}',
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
