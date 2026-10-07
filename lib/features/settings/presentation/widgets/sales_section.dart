import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/money.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';
import 'settings_shared.dart';

class SalesSection extends StatelessWidget {
  const SalesSection({super.key});

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
            title: SettingsStrings.salesTitle,
            subtitle: SettingsStrings.salesHint,
            children: [
              SettingsFieldGrid(
                children: [
                  const InputDecorator(
                    decoration: InputDecoration(labelText: SettingsStrings.currencyLabel),
                    child: Text(SettingsStrings.currencyValue),
                  ),
                  // Basis points are hundredths of a percent, which is exactly how
                  // money is split into minor units, so the same parser applies.
                  SettingsTextField(
                    initialValue: Money.formatPlain(draft.taxRateBasisPoints),
                    label: SettingsStrings.fieldTaxRate,
                    suffixText: '%',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (v) => cubit.edit((s) => s.copyWith(taxRateBasisPoints: Money.parseMinor(v) ?? -1)),
                  ),
                  SettingsTextField(
                    initialValue: '${draft.maxCashierDiscountPercent}',
                    label: SettingsStrings.fieldMaxDiscount,
                    suffixText: '%',
                    helperText: SettingsStrings.discountHint,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => cubit.edit((s) => s.copyWith(maxCashierDiscountPercent: int.tryParse(v) ?? -1)),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              const Padding(
                padding: EdgeInsets.only(top: AppDimens.spaceXs),
                child: Text(SettingsStrings.taxRateHint),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              SettingsSwitchRow(
                initialValue: draft.allowCreditSales,
                title: SettingsStrings.fieldAllowCredit,
                subtitle: SettingsStrings.creditHint,
                onChanged: (v) => cubit.edit((s) => s.copyWith(allowCreditSales: v)),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              const SettingsNote(message: SettingsStrings.rxRule),
              const SizedBox(height: AppDimens.spaceSm),
              const SettingsNote(message: SettingsStrings.notYetApplied, warning: true),
            ],
          ),
        );
      },
    );
  }
}
