import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../checkout/presentation/pages/pos_page.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../medicines/presentation/pages/medicines_page.dart';
import '../../../purchases/presentation/pages/purchases_page.dart';
import '../widgets/app_sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppModule _selected = AppModule.sales;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < AppDimens.compactBreakpoint;
          return Row(
            children: [
              AppSidebar(
                selected: _selected,
                compact: compact,
                onSelected: (module) => setState(() => _selected = module),
              ),
              Expanded(child: _body()),
            ],
          );
        },
      ),
    );
  }

  Widget _body() {
    switch (_selected) {
      case AppModule.sales:
        return const PosPage();
      case AppModule.dashboard:
        return const DashboardPage();
      case AppModule.purchases:
        return const PurchasesPage();
      case AppModule.medicines:
        return const MedicinesPage();
      default:
        return EmptyState(
          icon: _selected.icon,
          title: _selected.label,
          message: AppStrings.moduleNotBuilt,
        );
    }
  }
}
