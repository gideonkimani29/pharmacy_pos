import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/result/result.dart';
import 'package:pharmacy_pos/core/utils/money.dart';
import 'package:pharmacy_pos/features/settings/data/repositories/demo_settings_repository.dart';
import 'package:pharmacy_pos/features/settings/data/repositories/demo_user_repository.dart';
import 'package:pharmacy_pos/features/settings/domain/entities/app_settings.dart';
import 'package:pharmacy_pos/features/settings/domain/entities/app_user.dart';
import 'package:pharmacy_pos/features/settings/domain/settings_messages.dart';
import 'package:pharmacy_pos/features/settings/domain/usecases/get_settings.dart';
import 'package:pharmacy_pos/features/settings/domain/usecases/get_users.dart';
import 'package:pharmacy_pos/features/settings/domain/usecases/save_settings.dart';
import 'package:pharmacy_pos/features/settings/domain/usecases/save_user.dart';
import 'package:pharmacy_pos/features/settings/domain/usecases/set_user_active.dart';
import 'package:pharmacy_pos/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:pharmacy_pos/features/settings/presentation/settings_constants.dart';

final DateTime _now = DateTime(2026, 10, 7);

SettingsCubit _cubit() {
  final settings = DemoSettingsRepository();
  final users = DemoUserRepository(clock: () => _now);
  return SettingsCubit(
    getSettings: GetSettings(settings),
    saveSettings: SaveSettings(settings),
    getUsers: GetUsers(users),
    saveUser: SaveUser(users),
    setUserActive: SetUserActive(users),
  );
}

Future<AppSettings> _demoSettings() async =>
    (await DemoSettingsRepository().load() as Ok<AppSettings>).value;

void main() {
  group('tax rate typing', () {
    test('a typed percent becomes basis points with the same parser as money', () {
      expect(Money.parseMinor('16'), 1600);
      expect(Money.parseMinor('16.5'), 1650);
      expect(Money.parseMinor('0'), 0);
      expect(Money.parseMinor('abc'), isNull);
      expect(Money.formatPlain(1650), '16.50');
    });
  });

  group('SaveSettings', () {
    late AppSettings base;
    late SaveSettings useCase;

    setUp(() async {
      base = await _demoSettings();
      useCase = SaveSettings(DemoSettingsRepository());
    });

    Future<String?> failureOf(AppSettings s) async {
      final result = await useCase(s);
      return result is Err<AppSettings> ? result.failure.message : null;
    }

    test('accepts the demo settings and tidies text before saving', () async {
      final result = await useCase(base.copyWith(
        pharmacyName: '  Demo Pharmacy  ',
        phone: '+254 700-000 111',
        taxPin: ' a123456789b ',
      ));
      final saved = (result as Ok<AppSettings>).value;
      expect(saved.pharmacyName, 'Demo Pharmacy');
      expect(saved.phone, '+254700000111');
      expect(saved.taxPin, 'A123456789B');
    });

    test('needs a pharmacy name', () async {
      expect(await failureOf(base.copyWith(pharmacyName: '  ')), SettingsMessages.nameMissing);
    });

    test('phone, email and KRA PIN are checked only when entered', () async {
      expect(await failureOf(base.copyWith(phone: '', email: '', taxPin: '')), isNull);
      expect(await failureOf(base.copyWith(phone: '12345')), SettingsMessages.phoneInvalid);
      expect(await failureOf(base.copyWith(email: 'nope')), SettingsMessages.emailInvalid);
      expect(await failureOf(base.copyWith(taxPin: '123456789')), SettingsMessages.pinInvalid);
      expect(await failureOf(base.copyWith(taxPin: 'A12345678B')), SettingsMessages.pinInvalid);
    });

    test('tax rate must be between 0 and 100 percent', () async {
      expect(await failureOf(base.copyWith(taxRateBasisPoints: -1)), SettingsMessages.taxInvalid);
      expect(await failureOf(base.copyWith(taxRateBasisPoints: 10001)), SettingsMessages.taxInvalid);
      expect(await failureOf(base.copyWith(taxRateBasisPoints: 1600)), isNull);
      expect(await failureOf(base.copyWith(taxRateBasisPoints: 10000)), isNull);
    });

    test('discount limit, copies and footer length have limits', () async {
      expect(await failureOf(base.copyWith(maxCashierDiscountPercent: 101)), SettingsMessages.discountInvalid);
      expect(await failureOf(base.copyWith(maxCashierDiscountPercent: -1)), SettingsMessages.discountInvalid);
      expect(await failureOf(base.copyWith(receiptCopies: 0)), SettingsMessages.copiesInvalid);
      expect(await failureOf(base.copyWith(receiptCopies: 6)), SettingsMessages.copiesInvalid);
      expect(await failureOf(base.copyWith(receiptFooter: 'x' * 161)), SettingsMessages.footerTooLong);
      expect(await failureOf(base.copyWith(receiptFooter: 'x' * 160)), isNull);
    });
  });

  group('SaveUser and the admin rule', () {
    late DemoUserRepository repository;
    late SaveUser saveUser;
    late SetUserActive setActive;

    setUp(() {
      repository = DemoUserRepository(clock: () => _now);
      saveUser = SaveUser(repository);
      setActive = SetUserActive(repository);
    });

    UserDraft draft({
      String name = 'New Person',
      String email = 'new.person@demopharmacy.example',
      String phone = '',
      UserRole role = UserRole.cashier,
    }) {
      return UserDraft(name: name, email: email, phone: phone, role: role);
    }

    Future<String?> failureOf(UserDraft d, {String? id}) async {
      final result = await saveUser(d, id: id);
      return result is Err<AppUser> ? result.failure.message : null;
    }

    test('creates an active user and stores the email in lower case', () async {
      final result = await saveUser(draft(email: 'New.Person@DemoPharmacy.example'));
      final user = (result as Ok<AppUser>).value;
      expect(user.isActive, isTrue);
      expect(user.email, 'new.person@demopharmacy.example');
    });

    test('needs a name and a valid email; the phone is optional but checked when given', () async {
      expect(await failureOf(draft(name: ' ')), SettingsMessages.userNameMissing);
      expect(await failureOf(draft(email: '')), SettingsMessages.userEmailMissing);
      expect(await failureOf(draft(email: 'not-an-email')), SettingsMessages.emailInvalid);
      expect(await failureOf(draft(phone: '123')), SettingsMessages.phoneInvalid);
      expect(await failureOf(draft(phone: '')), isNull);
    });

    test('rejects an email already in use, in any letter case, but allows re-saving the same user', () async {
      expect(await failureOf(draft(email: 'ALEX.admin@demopharmacy.example')), SettingsMessages.duplicateEmail);
      expect(
        await failureOf(
          draft(name: 'Alex Admin', email: 'alex.admin@demopharmacy.example', role: UserRole.admin),
          id: 'u1',
        ),
        isNull,
      );
    });

    test('the only active admin cannot be demoted or deactivated', () async {
      expect(
        await failureOf(
          draft(name: 'Alex Admin', email: 'alex.admin@demopharmacy.example', role: UserRole.pharmacist),
          id: 'u1',
        ),
        SettingsMessages.lastAdmin,
      );
      final result = await setActive('u1', active: false);
      expect((result as Err<AppUser>).failure.message, SettingsMessages.lastAdmin);
    });

    test('once there is a second active admin, the first can be deactivated', () async {
      await saveUser(draft(name: 'Second Admin', email: 'second.admin@demopharmacy.example', role: UserRole.admin));
      final result = await setActive('u1', active: false);
      expect((result as Ok<AppUser>).value.isActive, isFalse);
    });

    test('non-admins can be deactivated freely', () async {
      final result = await setActive('u3', active: false);
      expect((result as Ok<AppUser>).value.isActive, isFalse);
    });
  });

  group('SettingsCubit', () {
    test('loading fills both the saved and the draft copy, with users sorted by name', () async {
      final cubit = _cubit();
      await cubit.load();
      expect(cubit.state.status, SettingsStatus.loaded);
      expect(cubit.state.draft, cubit.state.saved);
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.users.map((u) => u.name), ['Alex Admin', 'Casey Cashier', 'Pat Pharmacist', 'Sam Former']);
      await cubit.close();
    });

    test('editing makes the form dirty and discard puts it back, bumping the form version', () async {
      final cubit = _cubit();
      await cubit.load();
      final version = cubit.state.formVersion;
      cubit.edit((s) => s.copyWith(branchName: 'Kapsabet'));
      expect(cubit.state.isDirty, isTrue);
      cubit.discard();
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.draft!.branchName, 'Eldoret');
      expect(cubit.state.formVersion, version + 1);
      await cubit.close();
    });

    test('editing before anything has loaded does nothing', () async {
      final cubit = _cubit();
      cubit.edit((s) => s.copyWith(branchName: 'X'));
      expect(cubit.state.draft, isNull);
      await cubit.close();
    });

    test('saving an invalid form shows the message and keeps the edits', () async {
      final cubit = _cubit();
      await cubit.load();
      cubit.edit((s) => s.copyWith(pharmacyName: '  '));
      await cubit.save();
      expect(cubit.state.saveError, SettingsMessages.nameMissing);
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.saving, isFalse);
      cubit.edit((s) => s.copyWith(pharmacyName: 'Demo Pharmacy'));
      expect(cubit.state.saveError, isNull); // the message clears as soon as the user edits again
      await cubit.close();
    });

    test('saving a valid form stores the tidied values and clears the dirty state', () async {
      final cubit = _cubit();
      await cubit.load();
      final version = cubit.state.formVersion;
      cubit.edit((s) => s.copyWith(phone: '+254 700 000 111', taxPin: 'a123456789b', taxRateBasisPoints: 1600));
      await cubit.save();
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.saved!.phone, '+254700000111');
      expect(cubit.state.saved!.taxPin, 'A123456789B');
      expect(cubit.state.saved!.taxRateBasisPoints, 1600);
      expect(cubit.state.formVersion, version + 1);
      expect(cubit.state.notice!.message, SettingsStrings.saved);
      await cubit.close();
    });

    test('adding a user puts them in the sorted list; a duplicate email returns the message', () async {
      final cubit = _cubit();
      await cubit.load();
      final ok = await cubit.saveUser(const UserDraft(
        name: 'Bea Pharmacist',
        email: 'bea@demopharmacy.example',
        phone: '',
        role: UserRole.pharmacist,
      ));
      expect(ok, isNull);
      expect(cubit.state.users.map((u) => u.name).toList().indexOf('Bea Pharmacist'), 1);

      final dup = await cubit.saveUser(const UserDraft(
        name: 'Other',
        email: 'bea@demopharmacy.example',
        phone: '',
        role: UserRole.cashier,
      ));
      expect(dup, SettingsMessages.duplicateEmail);
      await cubit.close();
    });

    test('deactivating the only admin is refused with a notice and changes nothing', () async {
      final cubit = _cubit();
      await cubit.load();
      await cubit.toggleUserActive(cubit.state.users.firstWhere((u) => u.id == 'u1'));
      expect(cubit.state.notice!.message, SettingsMessages.lastAdmin);
      expect(cubit.state.users.firstWhere((u) => u.id == 'u1').isActive, isTrue);
      await cubit.close();
    });

    test('toggling a cashier updates the list and raises a notice', () async {
      final cubit = _cubit();
      await cubit.load();
      await cubit.toggleUserActive(cubit.state.users.firstWhere((u) => u.id == 'u3'));
      expect(cubit.state.users.firstWhere((u) => u.id == 'u3').isActive, isFalse);
      expect(cubit.state.notice!.message, SettingsStrings.userDeactivated('Casey Cashier'));
      await cubit.close();
    });

    test('reloading throws away unsaved edits', () async {
      final cubit = _cubit();
      await cubit.load();
      cubit.edit((s) => s.copyWith(branchName: 'Somewhere else'));
      await cubit.load();
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.draft!.branchName, 'Eldoret');
      await cubit.close();
    });
  });
}
