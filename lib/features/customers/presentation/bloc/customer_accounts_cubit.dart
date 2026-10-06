import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/customer_account.dart';
import '../../domain/usecases/get_customer_accounts.dart';
import '../../domain/usecases/receive_account_payment.dart';
import '../../domain/usecases/save_customer_account.dart';
import '../../domain/usecases/set_customer_active.dart';
import '../customers_constants.dart';

enum CustomerAccountsStatus { loading, loaded, failure }

enum CustomerFilter { all, owing, overLimit, inactive }

class CustomerNotice extends Equatable {
  const CustomerNotice({required this.id, required this.message});

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

class CustomerAccountsState extends Equatable {
  const CustomerAccountsState({
    this.status = CustomerAccountsStatus.loading,
    this.accounts = const [],
    this.query = '',
    this.filter = CustomerFilter.all,
    this.failure,
    this.notice,
  });

  final CustomerAccountsStatus status;
  final List<CustomerAccount> accounts;
  final String query;
  final CustomerFilter filter;
  final Failure? failure;
  final CustomerNotice? notice;

  static bool _matches(CustomerAccount c, CustomerFilter filter) => switch (filter) {
        CustomerFilter.all => true,
        CustomerFilter.owing => c.owes,
        CustomerFilter.overLimit => c.isOverLimit,
        CustomerFilter.inactive => !c.isActive,
      };

  int count(CustomerFilter filter) => accounts.where((c) => _matches(c, filter)).length;
  int get activeCount => accounts.where((c) => c.isActive).length;
  int get outstandingMinor => accounts.fold(0, (sum, c) => sum + c.balanceMinor);

  static const int _minLocalPhoneDigits = 4;

  /// Phones are stored as "+254722334455", but people type "0722334455".
  /// A query that starts with 0 is also matched without that leading 0.
  static bool _phoneMatches(String phone, String needle) {
    if (phone.contains(needle)) return true;
    final isLocalFormat = needle.length >= _minLocalPhoneDigits && needle.startsWith('0');
    return isLocalFormat && phone.contains(needle.substring(1));
  }

  /// Biggest debts first when looking at who owes; otherwise alphabetical.
  List<CustomerAccount> get visible {
    final needle = query.trim().toLowerCase();
    final rows = accounts.where((c) {
      if (!_matches(c, filter)) return false;
      if (needle.isEmpty) return true;
      return c.name.toLowerCase().contains(needle) ||
          _phoneMatches(c.phone, needle) ||
          c.email.toLowerCase().contains(needle);
    }).toList();

    if (filter == CustomerFilter.owing || filter == CustomerFilter.overLimit) {
      rows.sort((a, b) => b.balanceMinor.compareTo(a.balanceMinor));
    } else {
      rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return rows;
  }

  CustomerAccountsState copyWith({
    CustomerAccountsStatus? status,
    List<CustomerAccount>? accounts,
    String? query,
    CustomerFilter? filter,
    Failure? failure,
    CustomerNotice? notice,
  }) {
    return CustomerAccountsState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      failure: failure ?? this.failure,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [status, accounts, query, filter, failure, notice];
}

class CustomerAccountsCubit extends Cubit<CustomerAccountsState> {
  CustomerAccountsCubit({
    required GetCustomerAccounts getCustomerAccounts,
    required SaveCustomerAccount saveCustomerAccount,
    required SetCustomerActive setCustomerActive,
    required ReceiveAccountPayment receiveAccountPayment,
  })  : _getCustomerAccounts = getCustomerAccounts,
        _saveCustomerAccount = saveCustomerAccount,
        _setCustomerActive = setCustomerActive,
        _receiveAccountPayment = receiveAccountPayment,
        super(const CustomerAccountsState());

  final GetCustomerAccounts _getCustomerAccounts;
  final SaveCustomerAccount _saveCustomerAccount;
  final SetCustomerActive _setCustomerActive;
  final ReceiveAccountPayment _receiveAccountPayment;
  int _noticeSequence = 0;

  void _notify(String message) {
    emit(state.copyWith(notice: CustomerNotice(id: ++_noticeSequence, message: message)));
  }

  List<CustomerAccount> _replace(CustomerAccount updated) =>
      [for (final c in state.accounts) c.id == updated.id ? updated : c];

  Future<void> load() async {
    emit(CustomerAccountsState(
      status: CustomerAccountsStatus.loading,
      accounts: state.accounts,
      query: state.query,
      filter: state.filter,
      notice: state.notice,
    ));
    final result = await _getCustomerAccounts();
    switch (result) {
      case Ok<List<CustomerAccount>>(:final value):
        emit(CustomerAccountsState(
          status: CustomerAccountsStatus.loaded,
          accounts: value,
          query: state.query,
          filter: state.filter,
          notice: state.notice,
        ));
      case Err<List<CustomerAccount>>(:final failure):
        emit(CustomerAccountsState(
          status: CustomerAccountsStatus.failure,
          accounts: state.accounts,
          query: state.query,
          filter: state.filter,
          failure: failure,
          notice: state.notice,
        ));
    }
  }

  void setQuery(String query) => emit(state.copyWith(query: query));
  void setFilter(CustomerFilter filter) => emit(state.copyWith(filter: filter));

  /// Returns null on success, or the message to show in the form.
  Future<String?> save(CustomerDraft draft, {String? id}) async {
    final result = await _saveCustomerAccount(draft, id: id);
    switch (result) {
      case Ok<CustomerAccount>(:final value):
        final others = state.accounts.where((c) => c.id != value.id);
        emit(state.copyWith(accounts: [...others, value]));
        _notify(CustomersStrings.saved(value.name));
        return null;
      case Err<CustomerAccount>(:final failure):
        return failure.message;
    }
  }

  Future<void> toggleActive(CustomerAccount account) async {
    final result = await _setCustomerActive(account.id, active: !account.isActive);
    switch (result) {
      case Ok<CustomerAccount>(:final value):
        emit(state.copyWith(accounts: _replace(value)));
        _notify(value.isActive
            ? CustomersStrings.activated(value.name)
            : CustomersStrings.deactivated(value.name));
      case Err<CustomerAccount>(:final failure):
        _notify(failure.message);
    }
  }

  /// Returns null on success, or the message to show in the dialog.
  Future<String?> receivePayment(AccountPaymentDraft draft) async {
    final result = await _receiveAccountPayment(draft);
    switch (result) {
      case Ok<CustomerAccount>(:final value):
        emit(state.copyWith(accounts: _replace(value)));
        _notify(CustomersStrings.paymentReceived(
          Money.format(draft.amountMinor),
          value.name,
          Money.format(value.balanceMinor),
        ));
        return null;
      case Err<CustomerAccount>(:final failure):
        return failure.message;
    }
  }
}
