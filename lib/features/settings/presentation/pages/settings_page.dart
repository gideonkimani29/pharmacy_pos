import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';
import '../widgets/pharmacy_section.dart';
import '../widgets/receipts_section.dart';
import '../widgets/sales_section.dart';
import '../widgets/settings_nav.dart';
import '../widgets/settings_shared.dart';
import '../widgets/users_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // The shell builds this page each time the sidebar item is opened, so
    // the forms always start from what the server holds.
    context.read<SettingsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<SettingsCubit, SettingsState>(
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
              SettingsStrings.title,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              SettingsStrings.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const Expanded(child: _Body()),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) =>
          previous.status != current.status || previous.section != current.section,
      builder: (context, state) {
        if (state.draft == null) {
          if (state.status == SettingsStatus.failure) return _LoadFailed(message: state.failure?.message);
          return const Center(child: CircularProgressIndicator());
        }

        final section = switch (state.section) {
          SettingsSection.pharmacy => const PharmacySection(),
          SettingsSection.sales => const SalesSection(),
          SettingsSection.receipts => const ReceiptsSection(),
          SettingsSection.users => const UsersSection(),
        };
        final hasSaveBar = state.section != SettingsSection.users;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SingleChildScrollView(child: section)),
            if (hasSaveBar) ...[
              const SizedBox(height: AppDimens.spaceMd),
              const SettingsSaveBar(),
            ],
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < SettingsLayout.compactBreakpoint;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SettingsNav(compact: true),
                  const SizedBox(height: AppDimens.spaceLg),
                  Expanded(child: content),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsNav(compact: false),
                const SizedBox(width: AppDimens.spaceLg),
                Expanded(child: content),
              ],
            );
          },
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
          Text(SettingsStrings.loadFailed, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(message!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          OutlinedButton(
            onPressed: () => context.read<SettingsCubit>().load(),
            child: const Text(SettingsStrings.retry),
          ),
        ],
      ),
    );
  }
}
