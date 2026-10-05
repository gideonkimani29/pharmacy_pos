import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/get_customers.dart';

enum CustomersStatus { loading, loaded, failure }

class CustomersState extends Equatable {
  const CustomersState({this.status = CustomersStatus.loading, this.customers = const []});

  final CustomersStatus status;
  final List<Customer> customers;

  @override
  List<Object?> get props => [status, customers];
}

class CustomersCubit extends Cubit<CustomersState> {
  CustomersCubit({required GetCustomers getCustomers})
      : _getCustomers = getCustomers,
        super(const CustomersState());

  final GetCustomers _getCustomers;

  Future<void> load() async {
    emit(const CustomersState());
    final result = await _getCustomers();
    switch (result) {
      case Ok<List<Customer>>(:final value):
        emit(CustomersState(status: CustomersStatus.loaded, customers: value));
      case Err<List<Customer>>():
        emit(const CustomersState(status: CustomersStatus.failure));
    }
  }
}
