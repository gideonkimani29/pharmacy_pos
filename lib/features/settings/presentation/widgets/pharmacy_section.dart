import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';
import 'settings_shared.dart';

class PharmacySection extends StatelessWidget {
  const PharmacySection({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) => previous.formVersion != current.formVersion,
      builder: (context, state) {
        final draft = state.draft!;
        return KeyedSubtree(
          key: ValueKey(state.formVersion),
          child: SettingsCard(
            title: SettingsStrings.pharmacyTitle,
            subtitle: SettingsStrings.pharmacyHint,
            children: [
              SettingsFieldGrid(
                children: [
                  SettingsTextField(
                    initialValue: draft.pharmacyName,
                    label: SettingsStrings.fieldName,
                    prefixIcon: Icons.storefront_outlined,
                    onChanged: (v) => cubit.edit((s) => s.copyWith(pharmacyName: v)),
                  ),
                  SettingsTextField(
                    initialValue: draft.branchName,
                    label: SettingsStrings.fieldBranch,
                    onChanged: (v) => cubit.edit((s) => s.copyWith(branchName: v)),
                  ),
                  SettingsTextField(
                    initialValue: draft.address,
                    label: SettingsStrings.fieldAddress,
                    prefixIcon: Icons.place_outlined,
                    onChanged: (v) => cubit.edit((s) => s.copyWith(address: v)),
                  ),
                  SettingsTextField(
                    initialValue: draft.phone,
                    label: SettingsStrings.fieldPhone,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => cubit.edit((s) => s.copyWith(phone: v)),
                  ),
                  SettingsTextField(
                    initialValue: draft.email,
                    label: SettingsStrings.fieldEmail,
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => cubit.edit((s) => s.copyWith(email: v)),
                  ),
                  SettingsTextField(
                    initialValue: draft.taxPin,
                    label: SettingsStrings.fieldTaxPin,
                    helperText: SettingsStrings.taxPinHint,
                    onChanged: (v) => cubit.edit((s) => s.copyWith(taxPin: v)),
                  ),
                  SettingsTextField(
                    initialValue: draft.licenceNumber,
                    label: SettingsStrings.fieldLicence,
                    helperText: SettingsStrings.licenceHint,
                    onChanged: (v) => cubit.edit((s) => s.copyWith(licenceNumber: v)),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
            ],
          ),
        );
      },
    );
  }
}
