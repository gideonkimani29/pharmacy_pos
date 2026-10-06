import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/features/checkout/domain/entities/payment.dart';
import 'package:pharmacy_pos/features/customers/data/repositories/demo_customer_account_repository.dart';
import 'package:pharmacy_pos/features/customers/domain/customer_messages.dart';
import 'package:pharmacy_pos/features/customers/domain/entities/customer_account.dart';
import 'package:pharmacy_pos/features/customers/domain/usecases/get_customer_accounts.dart';
import 'package:pharmacy_pos/features/customers/domain/usecases/receive_account_payment.dart';
import 'package:pharmacy_pos/features/customers/domain/usecases/save_customer_account.dart';
import 'package:pharmacy_pos/features/customers/domain/usecases/set_customer_active.dart';
import 'package:pharmacy_pos/features/customers/presentation/bloc/customer_accounts_cubit.dart';

CustomerDraft draft({
  String name = 'New Customer',
  String phone = '+254755000111',
  String email = '',
  int limit = 100000,
}) {
  return CustomerDraft(name: name, phone: phone, email: email, creditLimitMinor: limit);
}

CustomerAccountsCubit buildCubit() {
  final repository = DemoCustomerAccountRepository(clock: () => DateTime(2026, 10, 6));
  return CustomerAccountsCubit(
    getCustomerAccounts: GetCustomerAccounts(repository),
    saveCustomerAccount: SaveCustomerAccount(repository),
    setCustomerActive: SetCustomerActive(repository),
    receiveAccountPayment: ReceiveAccountPayment(repository),
  );
}

void main() {
  group('CustomerAccount', () {
    const account = CustomerAccount(
      id: 'x',
      name: 'X',
      phone: '+254700000009',
      email: '',
      creditLimitMinor: 1000,
      balanceMinor: 400,
      isActive: true,
    );

    test('available credit is the limit minus what is owed, never negative', () {
      expect(account.availableCreditMinor, 600);
      expect(account.copyWith(balanceMinor: 1000).availableCreditMinor, 0);
      expect(account.copyWith(balanceMinor: 1500).availableCreditMinor, 0);
    });

    test('over limit only when the balance is above the limit, not at it', () {
      expect(account.isOverLimit, isFalse);
      expect(account.copyWith(balanceMinor: 1000).isOverLimit, isFalse);
      expect(account.copyWith(balanceMinor: 1001).isOverLimit, isTrue);
    });
  });

  group('SaveCustomerAccount', () {
    late SaveCustomerAccount useCase;

    setUp(() {
      useCase = SaveCustomerAccount(DemoCustomerAccountRepository(clock: () => DateTime(2026, 10, 6)));
    });

    Future<String?> failureOf(CustomerDraft d, {String? id}) async {
      final result = await useCase(d, id: id);
      return result is Err<CustomerAccount> ? result.failure.message : null;
    }

    test('creates an active customer with no balance', () async {
      final result = await useCase(draft());
      final account = (result as Ok<CustomerAccount>).value;
      expect(account.balanceMinor, 0);
      expect(account.isActive, isTrue);
    });

    test('stores the phone number without spaces or dashes', () async {
      final result = await useCase(draft(phone: '+254 755-000 111'));
      expect((result as Ok<CustomerAccount>).value.phone, '+254755000111');
    });

    test('rejects a missing name, a bad phone, a bad email and a negative limit', () async {
      expect(await failureOf(draft(name: '  ')), CustomerMessages.nameMissing);
      expect(await failureOf(draft(phone: '12345')), CustomerMessages.phoneInvalid);
      expect(await failureOf(draft(email: 'not-an-email')), CustomerMessages.emailInvalid);
      expect(await failureOf(draft(limit: -1)), CustomerMessages.limitInvalid);
    });

    test('accepts an empty email', () async {
      expect(await failureOf(draft(email: '')), isNull);
    });

    test('rejects a phone already in use, even when typed with spaces, but allows re-saving the same customer', () async {
      expect(await failureOf(draft(phone: '+254700000001')), CustomerMessages.duplicatePhone);
      expect(await failureOf(draft(phone: '+254 700 000 001')), CustomerMessages.duplicatePhone);
      expect(await failureOf(draft(name: 'Mary Chebet', phone: '+254700000001'), id: 'c1'), isNull);
    });
  });

  group('ReceiveAccountPayment', () {
    late ReceiveAccountPayment useCase;

    setUp(() {
      useCase = ReceiveAccountPayment(DemoCustomerAccountRepository(clock: () => DateTime(2026, 10, 6)));
    });

    Future<String?> failureOf(AccountPaymentDraft d) async {
      final result = await useCase(d);
      return result is Err<CustomerAccount> ? result.failure.message : null;
    }

    test('reduces the balance by the amount received', () async {
      final result = await useCase(
        const AccountPaymentDraft(customerId: 'c1', amountMinor: 50000, method: PaymentMethod.cash),
      );
      expect((result as Ok<CustomerAccount>).value.balanceMinor, 70000);
    });

    test('rejects a zero amount', () async {
      expect(
        await failureOf(const AccountPaymentDraft(customerId: 'c1', amountMinor: 0, method: PaymentMethod.cash)),
        CustomerMessages.paymentAmountInvalid,
      );
    });

    test('mobile and card payments need a reference code', () async {
      expect(
        await failureOf(const AccountPaymentDraft(customerId: 'c1', amountMinor: 1000, method: PaymentMethod.mobile)),
        isNotNull,
      );
      expect(
        await failureOf(const AccountPaymentDraft(
          customerId: 'c1',
          amountMinor: 1000,
          method: PaymentMethod.mobile,
          reference: 'QGH7XYZ123',
        )),
        isNull,
      );
    });

    test('rejects more than the customer owes, and a customer who owes nothing', () async {
      expect(
        await failureOf(const AccountPaymentDraft(customerId: 'c1', amountMinor: 120001, method: PaymentMethod.cash)),
        CustomerMessages.paymentExceedsBalance,
      );
      expect(
        await failureOf(const AccountPaymentDraft(customerId: 'c4', amountMinor: 1000, method: PaymentMethod.cash)),
        CustomerMessages.noBalance,
      );
    });
  });

  group('CustomerAccountsCubit', () {
    test('counts and totals come from the loaded accounts', () async {
      final cubit = buildCubit();
      await cubit.load();
      expect(cubit.state.activeCount, 7); // Peter Otieno is inactive
      expect(cubit.state.outstandingMinor, 7000000);
      expect(cubit.state.count(CustomerFilter.owing), 5);
      expect(cubit.state.count(CustomerFilter.overLimit), 1); // Kapsabet SACCO; Faith is exactly at her limit
      expect(cubit.state.count(CustomerFilter.inactive), 1);
      await cubit.close();
    });

    test('the Owing filter lists the biggest debts first', () async {
      final cubit = buildCubit();
      await cubit.load();
      cubit.setFilter(CustomerFilter.owing);
      expect(cubit.state.visible.map((c) => c.id), ['c2', 'c3', 'c8', 'c6', 'c1']);
      await cubit.close();
    });

    test('search matches name, phone and email', () async {
      final cubit = buildCubit();
      await cubit.load();
      cubit.setQuery('grace');
      expect(cubit.state.visible.single.id, 'c5');
      cubit.setQuery('0722334455');
      expect(cubit.state.visible.single.id, 'c6');
      cubit.setQuery('ugclinic');
      expect(cubit.state.visible.single.id, 'c2');
      await cubit.close();
    });

    test('receiving a payment updates the balance, the totals and raises a notice', () async {
      final cubit = buildCubit();
      await cubit.load();
      final error = await cubit.receivePayment(
        const AccountPaymentDraft(customerId: 'c1', amountMinor: 120000, method: PaymentMethod.cash),
      );
      expect(error, isNull);
      expect(cubit.state.accounts.firstWhere((c) => c.id == 'c1').balanceMinor, 0);
      expect(cubit.state.outstandingMinor, 6880000);
      expect(cubit.state.count(CustomerFilter.owing), 4);
      expect(cubit.state.notice, isNotNull);
      await cubit.close();
    });

    test('a rejected payment returns the message and changes nothing', () async {
      final cubit = buildCubit();
      await cubit.load();
      final error = await cubit.receivePayment(
        const AccountPaymentDraft(customerId: 'c1', amountMinor: 999999, method: PaymentMethod.cash),
      );
      expect(error, CustomerMessages.paymentExceedsBalance);
      expect(cubit.state.outstandingMinor, 7000000);
      await cubit.close();
    });

    test('saving a new customer adds it; a duplicate phone returns the message', () async {
      final cubit = buildCubit();
      await cubit.load();
      expect(await cubit.save(draft(name: 'Zed New', phone: '+254766000222')), isNull);
      expect(cubit.state.accounts.length, 9);
      expect(await cubit.save(draft(phone: '+254700000002')), CustomerMessages.duplicatePhone);
      await cubit.close();
    });

    test('deactivating a customer moves them to the Inactive filter', () async {
      final cubit = buildCubit();
      await cubit.load();
      await cubit.toggleActive(cubit.state.accounts.firstWhere((c) => c.id == 'c5'));
      expect(cubit.state.count(CustomerFilter.inactive), 2);
      expect(cubit.state.activeCount, 6);
      await cubit.close();
    });
  });
}
