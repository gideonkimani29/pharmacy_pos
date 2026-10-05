import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../bloc/medicines_cubit.dart';
import '../medicines_constants.dart';

/// Search box and filter chips (with live counts).
class MedicineToolbar extends StatelessWidget {
  const MedicineToolbar({super.key});

  static String _label(MedicineFilter filter) => switch (filter) {
        MedicineFilter.all => MedicinesStrings.filterAll,
        MedicineFilter.lowStock => MedicinesStrings.filterLow,
        MedicineFilter.outOfStock => MedicinesStrings.filterOut,
        MedicineFilter.prescription => MedicinesStrings.filterRx,
        MedicineFilter.inactive => MedicinesStrings.filterInactive,
      };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MedicinesCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: cubit.setQuery,
          decoration: const InputDecoration(
            hintText: MedicinesStrings.searchHint,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        BlocBuilder<MedicinesCubit, MedicinesState>(
          buildWhen: (previous, current) =>
              previous.filter != current.filter || previous.medicines != current.medicines,
          builder: (context, state) {
            return Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              children: [
                for (final filter in MedicineFilter.values)
                  ChoiceChip(
                    label: Text(MedicinesStrings.filterLabel(_label(filter), state.count(filter))),
                    selected: state.filter == filter,
                    onSelected: (_) => cubit.setFilter(filter),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
