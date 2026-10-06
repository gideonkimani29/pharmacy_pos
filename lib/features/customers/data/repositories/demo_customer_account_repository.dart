import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/customer_messages.dart';
import '../../domain/entities/customer_account.dart';
import '../../domain/repositories/customer_account_repository.dart';

/// In-memory customers so the module can be built before the Go API exists.
/// Replace with a REST-backed repository.
class DemoCustomerAccountRepository implements CustomerAccountRepository {
  DemoCustomerAccountRepository({DateTime Function()? clock}) {
    _items.addAll(_seed((clock ?? DateTime.now)()));
  }

  static const Duration _latency = Duration(milliseconds: 250);
  static const String _idPrefix = 'c';
  static const int _firstNewId = 100;

  final List<CustomerAccount> _items = [];
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
      return const Err<CustomerAccount>(ValidationFailure(CustomerMessages.duplicatePhone));
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
    if (index < 0) return const Err<CustomerAccount>(ValidationFailure(CustomerMessages.notFound));
    if (_phoneTaken(draft.phone, exceptId: id)) {
      return const Err<CustomerAccount>(ValidationFailure(CustomerMessages.duplicatePhone));
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
  Future<Result<CustomerAccount>> setActive(String id, {required bool active}) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((c) => c.id == id);
    if (index < 0) return const Err<CustomerAccount>(ValidationFailure(CustomerMessages.notFound));
    _items[index] = _items[index].copyWith(isActive: active);
    return Ok(_items[index]);
  }

  @override
  Future<Result<CustomerAccount>> receivePayment(AccountPaymentDraft draft) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((c) => c.id == draft.customerId);
    if (index < 0) return const Err<CustomerAccount>(ValidationFailure(CustomerMessages.notFound));

    final balance = _items[index].balanceMinor;
    if (balance <= 0) return const Err<CustomerAccount>(ValidationFailure(CustomerMessages.noBalance));
    if (draft.amountMinor > balance) {
      return const Err<CustomerAccount>(ValidationFailure(CustomerMessages.paymentExceedsBalance));
    }
    _items[index] = _items[index].copyWith(balanceMinor: balance - draft.amountMinor);
    return Ok(_items[index]);
  }

  bool _phoneTaken(String phone, {required String? exceptId}) =>
      _items.any((c) => c.id != exceptId && c.phone == phone);

  static List<CustomerAccount> _seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime ago(int days) => today.subtract(Duration(days: days));

    return [
      CustomerAccount(id: 'c1', name: 'Mary Chebet', phone: '+254700000001', email: 'mary.chebet@example.com', creditLimitMinor: 500000, balanceMinor: 120000, isActive: true, lastPurchaseOn: ago(2)),
      CustomerAccount(id: 'c2', name: 'Uasin Gishu Community Clinic', phone: '+254700000002', email: 'pharmacy@ugclinic.example', creditLimitMinor: 5000000, balanceMinor: 3250000, isActive: true, lastPurchaseOn: ago(1)),
      CustomerAccount(id: 'c3', name: 'Kapsabet SACCO Staff Account', phone: '+254700000003', email: '', creditLimitMinor: 2000000, balanceMinor: 2350000, isActive: true, lastPurchaseOn: ago(6)),
      CustomerAccount(id: 'c4', name: 'John Kiprono', phone: '+254700000004', email: '', creditLimitMinor: 0, balanceMinor: 0, isActive: true, lastPurchaseOn: ago(14)),
      CustomerAccount(id: 'c5', name: 'Grace Wanjiku', phone: '+254712345678', email: 'grace.w@example.com', creditLimitMinor: 1000000, balanceMinor: 0, isActive: true, lastPurchaseOn: ago(4)),
      CustomerAccount(id: 'c6', name: 'Eldoret Day Care Centre', phone: '+254722334455', email: '', creditLimitMinor: 1500000, balanceMinor: 480000, isActive: true, lastPurchaseOn: ago(9)),
      CustomerAccount(id: 'c7', name: 'Peter Otieno', phone: '+254733445566', email: '', creditLimitMinor: 300000, balanceMinor: 0, isActive: false, lastPurchaseOn: ago(210)),
      CustomerAccount(id: 'c8', name: 'Faith Jepchirchir', phone: '+254744556677', email: 'faith.j@example.com', creditLimitMinor: 800000, balanceMinor: 800000, isActive: true, lastPurchaseOn: ago(11)),
    ];
  }
}
