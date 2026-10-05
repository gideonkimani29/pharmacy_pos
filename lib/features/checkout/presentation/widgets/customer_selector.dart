import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/customer.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/customers_cubit.dart';

class CustomerSelector extends StatelessWidget {
  const CustomerSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomersCubit, CustomersState>(
      builder: (context, customers) {
        return BlocBuilder<CartBloc, CartState>(
          buildWhen: (previous, current) =>
              previous.customer != current.customer || previous.isSubmitting != current.isSubmitting,
          builder: (context, cart) {
            return DropdownButtonFormField<Customer?>(
              value: cart.customer,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: AppStrings.selectCustomer,
                prefixIcon: const Icon(Icons.person_outline),
                errorText: customers.status == CustomersStatus.failure
                    ? AppStrings.customersLoadFailed
                    : null,
              ),
              items: [
                const DropdownMenuItem<Customer?>(value: null, child: Text(AppStrings.noCustomer)),
                for (final customer in customers.customers)
                  DropdownMenuItem<Customer?>(value: customer, child: Text(customer.name)),
              ],
              onChanged: cart.isSubmitting
                  ? null
                  : (customer) => context.read<CartBloc>().add(CartCustomerSelected(customer)),
            );
          },
        );
      },
    );
  }
}
