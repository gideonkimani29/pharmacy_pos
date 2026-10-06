import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../bloc/customer_accounts_cubit.dart';
import '../customers_constants.dart';

/// Search box and filter chips (with live counts).
class CustomerToolbar extends StatelessWidget {
  const CustomerToolbar({super.key});

  static String _label(CustomerFilter filter) => switch (filter) {
        CustomerFilter.all => CustomersStrings.filterAll,
        CustomerFilter.owing => CustomersStrings.filterOwing,
        CustomerFilter.overLimit => CustomersStrings.filterOverLimit,
        CustomerFilter.inactive => CustomersStrings.filterInactive,
      };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerAccountsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: cubit.setQuery,
          decoration: const InputDecoration(
            hintText: CustomersStrings.searchHint,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        BlocBuilder<CustomerAccountsCubit, CustomerAccountsState>(
          buildWhen: (previous, current) =>
              previous.filter != current.filter || previous.accounts != current.accounts,
          builder: (context, state) {
            return Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              children: [
                for (final filter in CustomerFilter.values)
                  ChoiceChip(
                    label: Text(CustomersStrings.filterLabel(_label(filter), state.count(filter))),
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
