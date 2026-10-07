import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../checkout/presentation/widgets/status_pill.dart';
import '../../domain/entities/app_user.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';
import 'settings_shared.dart';
import 'user_form_dialog.dart';

class UsersSection extends StatelessWidget {
  const UsersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) => previous.users != current.users,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: AppColors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceLg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                SettingsStrings.usersTitle,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                SettingsStrings.usersHint,
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => UserFormDialog.show(context),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text(SettingsStrings.addUser),
                        ),
                      ],
                    ),
                  ),
                  const _HeaderRow(),
                  if (state.users.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceXl),
                      child: Text(
                        SettingsStrings.noUsers,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (final user in state.users) ...[
                      const Divider(height: 1),
                      _UserRow(key: ValueKey(user.id), user: user),
                    ],
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const _RolesCard(),
          ],
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

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
          Expanded(flex: SettingsLayout.userNameFlex, child: Text(SettingsStrings.colUser, style: style)),
          SizedBox(width: SettingsLayout.roleColumnWidth, child: Text(SettingsStrings.colRole, style: style)),
          SizedBox(
            width: SettingsLayout.signInColumnWidth,
            child: Text(SettingsStrings.colLastSignIn, style: style),
          ),
          SizedBox(
            width: SettingsLayout.statusColumnWidth,
            child: Center(child: Text(SettingsStrings.colActive, style: style)),
          ),
          SizedBox(
            width: SettingsLayout.editColumnWidth,
            child: Center(child: Text(SettingsStrings.colEdit, style: style)),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastSignIn = user.lastSignInAt;
    final (Color fg, Color bg) = switch (user.role) {
      UserRole.admin => (AppColors.rxFg, AppColors.rxBg),
      UserRole.pharmacist => (AppColors.infoFg, AppColors.infoBg),
      UserRole.cashier => (AppColors.neutralFg, AppColors.neutralBg),
    };

    return Opacity(
      opacity: user.isActive ? 1 : SettingsLayout.inactiveOpacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
        child: Row(
          children: [
            Expanded(
              flex: SettingsLayout.userNameFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: SettingsLayout.roleColumnWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(label: SettingsStrings.roleLabel(user.role), foreground: fg, background: bg),
              ),
            ),
            SizedBox(
              width: SettingsLayout.signInColumnWidth,
              child: Text(lastSignIn == null ? SettingsStrings.never : AppDates.short(lastSignIn)),
            ),
            SizedBox(
              width: SettingsLayout.statusColumnWidth,
              child: Center(
                child: Tooltip(
                  message: SettingsStrings.activeTooltip,
                  child: Switch(
                    value: user.isActive,
                    onChanged: (_) => context.read<SettingsCubit>().toggleUserActive(user),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: SettingsLayout.editColumnWidth,
              child: Center(
                child: IconButton(
                  tooltip: SettingsStrings.editTooltip,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => UserFormDialog.show(context, existing: user),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolesCard extends StatelessWidget {
  const _RolesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      title: SettingsStrings.rolesTitle,
      children: [
        for (final role in UserRole.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: SettingsLayout.roleColumnWidth,
                  child: Text(
                    SettingsStrings.roleLabel(role),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    SettingsStrings.roleSummary(role),
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
