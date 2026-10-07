import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/save_settings.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';
import 'settings_shared.dart';

class ReceiptsSection extends StatelessWidget {
  const ReceiptsSection({super.key});

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
            title: SettingsStrings.receiptsTitle,
            subtitle: SettingsStrings.receiptsHint,
            children: [
              SettingsFieldGrid(
                children: [
                  DropdownButtonFormField<PrinterConnection>(
                    value: draft.printerConnection,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: SettingsStrings.fieldPrinter),
                    items: [
                      for (final connection in PrinterConnection.values)
                        DropdownMenuItem(value: connection, child: Text(SettingsStrings.printerLabel(connection))),
                    ],
                    onChanged: (v) {
                      if (v != null) cubit.edit((s) => s.copyWith(printerConnection: v));
                    },
                  ),
                  DropdownButtonFormField<PaperWidth>(
                    value: draft.paperWidth,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: SettingsStrings.fieldPaper),
                    items: [
                      for (final width in PaperWidth.values)
                        DropdownMenuItem(value: width, child: Text(SettingsStrings.paperLabel(width))),
                    ],
                    onChanged: (v) {
                      if (v != null) cubit.edit((s) => s.copyWith(paperWidth: v));
                    },
                  ),
                  SettingsTextField(
                    initialValue: '${draft.receiptCopies}',
                    label: SettingsStrings.fieldCopies,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => cubit.edit((s) => s.copyWith(receiptCopies: int.tryParse(v) ?? 0)),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              SettingsSwitchRow(
                initialValue: draft.autoPrintReceipt,
                title: SettingsStrings.fieldAutoPrint,
                onChanged: (v) => cubit.edit((s) => s.copyWith(autoPrintReceipt: v)),
              ),
              SettingsSwitchRow(
                initialValue: draft.printPharmacyDetails,
                title: SettingsStrings.fieldPrintDetails,
                onChanged: (v) => cubit.edit((s) => s.copyWith(printPharmacyDetails: v)),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              SettingsTextField(
                initialValue: draft.receiptFooter,
                label: SettingsStrings.fieldFooter,
                helperText: SettingsStrings.footerHint,
                maxLength: SaveSettings.maxFooterLength,
                maxLines: SettingsLayout.footerLines,
                onChanged: (v) => cubit.edit((s) => s.copyWith(receiptFooter: v)),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              const SettingsNote(message: SettingsStrings.printerNote, warning: true),
            ],
          ),
        );
      },
    );
  }
}
