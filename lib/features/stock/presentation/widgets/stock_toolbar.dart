import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../bloc/stock_cubit.dart';
import '../stock_constants.dart';

/// Search, view switch (batches / by medicine) and expiry filter chips.
class StockToolbar extends StatelessWidget {
  const StockToolbar({super.key});

  static String _label(StockFilter filter) => switch (filter) {
        StockFilter.all => StockStrings.filterAll,
        StockFilter.expired => StockStrings.filterExpired,
        StockFilter.within30 => StockStrings.filter30,
        StockFilter.within60 => StockStrings.filter60,
        StockFilter.within90 => StockStrings.filter90,
        StockFilter.empty => StockStrings.filterEmpty,
      };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StockCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: cubit.setQuery,
                decoration: const InputDecoration(
                  hintText: StockStrings.searchHint,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spaceLg),
            BlocBuilder<StockCubit, StockState>(
              buildWhen: (previous, current) => previous.view != current.view,
              builder: (context, state) => SegmentedButton<StockView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: StockView.batches,
                    label: Text(StockStrings.viewBatches),
                    icon: Icon(Icons.layers_outlined),
                  ),
                  ButtonSegment(
                    value: StockView.medicines,
                    label: Text(StockStrings.viewMedicines),
                    icon: Icon(Icons.medication_outlined),
                  ),
                ],
                selected: {state.view},
                onSelectionChanged: (selection) => cubit.setView(selection.first),
              ),
            ),
          ],
        ),
        BlocBuilder<StockCubit, StockState>(
          buildWhen: (previous, current) =>
              previous.view != current.view ||
              previous.filter != current.filter ||
              previous.batches != current.batches,
          builder: (context, state) {
            if (state.view != StockView.batches) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppDimens.spaceMd),
              child: Wrap(
                spacing: AppDimens.spaceSm,
                runSpacing: AppDimens.spaceSm,
                children: [
                  for (final filter in StockFilter.values)
                    ChoiceChip(
                      label: Text(StockStrings.filterLabel(_label(filter), state.count(filter))),
                      selected: state.filter == filter,
                      onSelected: (_) => cubit.setFilter(filter),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
