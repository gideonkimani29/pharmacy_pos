import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/customer_messages.dart';
import '../../domain/entities/customer_account.dart';
import '../../domain/repositories/customer_account_repository.dart';

class DemoCustomerAccountRepository implements CustomerAccountRepository {
  DemoCustomerAccountRepository({List<CustomerAccount> customers = const []})
      : _items = [...customers];

  static const Duration _latency = Duration(milliseconds: 250);
  static const String _idPrefix = 'c';
  static const int _firstNewId = 100;

  final List<CustomerAccount> _items;
  int _counter = _firstNewId;

  @override
  Future<Result<List<CustomerAccount>>> list() async {
    await Future<void>.delayed(_latency);
    return Ok([..._items]);
  }

  @override
  Future<Result<CustomerAccount>> create(CustomerDraft draft) async {
    await Future<void>.delayed(_latency);
    if (_phoneTaken(draft.phone, exceptId: null)) {
      return const Err<CustomerAccount>(
          ValidationFailure(CustomerMessages.duplicatePhone));
    }
    final account = CustomerAccount(
      id: '$_idPrefix${_counter++}',
      name: draft.name,
      phone: draft.phone,
      email: draft.email,
      creditLimitMinor: draft.creditLimitMinor,
      balanceMinor: 0,
      isActive: true,
    );
    _items.add(account);
    return Ok(account);
  }

  @override
  Future<Result<CustomerAccount>> update(String id, CustomerDraft draft) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((c) => c.id == id);
    if (index < 0) {
      return const Err<CustomerAccount>(
          ValidationFailure(CustomerMessages.notFound));
    }
    if (_phoneTaken(draft.phone, exceptId: id)) {
      return const Err<CustomerAccount>(
          ValidationFailure(CustomerMessages.duplicatePhone));
    }
    final current = _items[index];
    _items[index] = CustomerAccount(
      id: id,
      name: draft.name,
      phone: draft.phone,
      email: draft.email,
      creditLimitMinor: draft.creditLimitMinor,
      balanceMinor: current.balanceMinor,
      isActive: current.isActive,
      lastPurchaseOn: current.lastPurchaseOn,
    );
    return Ok(_items[index]);
  }

  @override
  Future<Result<CustomerAccount>> setActive(String id,
      {required bool active}) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((c) => c.id == id);
    if (index < 0) {
      return const Err<CustomerAccount>(
          ValidationFailure(CustomerMessages.notFound));
    }
    _items[index] = _items[index].copyWith(isActive: active);
    return Ok(_items[index]);
  }

  @override
  Future<Result<CustomerAccount>> receivePayment(
      AccountPaymentDraft draft) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((c) => c.id == draft.customerId);
    if (index < 0) {
      return const Err<CustomerAccount>(
          ValidationFailure(CustomerMessages.notFound));
    }

    final balance = _items[index].balanceMinor;
    if (balance <= 0) {
      return const Err<CustomerAccount>(
          ValidationFailure(CustomerMessages.noBalance));
    }
    if (draft.amountMinor > balance) {
      return const Err<CustomerAccount>(
          ValidationFailure(CustomerMessages.paymentExceedsBalance));
    }
    _items[index] =
        _items[index].copyWith(balanceMinor: balance - draft.amountMinor);
    return Ok(_items[index]);
  }

  bool _phoneTaken(String phone, {required String? exceptId}) =>
      _items.any((c) => c.id != exceptId && c.phone == phone);
}
