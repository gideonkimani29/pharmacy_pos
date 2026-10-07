import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/settings_messages.dart';

/// In-memory users so the module can be built before the Go API exists.
/// Replace with a REST-backed repository.
class DemoUserRepository implements UserRepository {
  DemoUserRepository({DateTime Function()? clock}) {
    _items.addAll(_seed((clock ?? DateTime.now)()));
  }

  static const Duration _latency = Duration(milliseconds: 250);
  static const String _idPrefix = 'u';
  static const int _firstNewId = 100;

  final List<AppUser> _items = [];
  int _counter = _firstNewId;

  @override
  Future<Result<List<AppUser>>> list() async {
    await Future<void>.delayed(_latency);
    return Ok([..._items]);
  }

  @override
  Future<Result<AppUser>> create(UserDraft draft) async {
    await Future<void>.delayed(_latency);
    if (_emailTaken(draft.email, exceptId: null)) {
      return const Err<AppUser>(ValidationFailure(SettingsMessages.duplicateEmail));
    }
    final user = AppUser(
      id: '$_idPrefix${_counter++}',
      name: draft.name,
      email: draft.email,
      phone: draft.phone,
      role: draft.role,
      isActive: true,
    );
    _items.add(user);
    return Ok(user);
  }

  @override
  Future<Result<AppUser>> update(String id, UserDraft draft) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((u) => u.id == id);
    if (index < 0) return const Err<AppUser>(ValidationFailure(SettingsMessages.userNotFound));
    if (_emailTaken(draft.email, exceptId: id)) {
      return const Err<AppUser>(ValidationFailure(SettingsMessages.duplicateEmail));
    }

    final current = _items[index];
    final losesAdmin = current.role == UserRole.admin && draft.role != UserRole.admin;
    if (losesAdmin && current.isActive && _activeAdmins == 1) {
      return const Err<AppUser>(ValidationFailure(SettingsMessages.lastAdmin));
    }

    _items[index] = AppUser(
      id: id,
      name: draft.name,
      email: draft.email,
      phone: draft.phone,
      role: draft.role,
      isActive: current.isActive,
      lastSignInAt: current.lastSignInAt,
    );
    return Ok(_items[index]);
  }

  @override
  Future<Result<AppUser>> setActive(String id, {required bool active}) async {
    await Future<void>.delayed(_latency);
    final index = _items.indexWhere((u) => u.id == id);
    if (index < 0) return const Err<AppUser>(ValidationFailure(SettingsMessages.userNotFound));

    final current = _items[index];
    if (!active && current.role == UserRole.admin && current.isActive && _activeAdmins == 1) {
      return const Err<AppUser>(ValidationFailure(SettingsMessages.lastAdmin));
    }
    _items[index] = current.copyWith(isActive: active);
    return Ok(_items[index]);
  }

  int get _activeAdmins => _items.where((u) => u.role == UserRole.admin && u.isActive).length;

  bool _emailTaken(String email, {required String? exceptId}) =>
      _items.any((u) => u.id != exceptId && u.email.toLowerCase() == email.toLowerCase());

  static List<AppUser> _seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime ago(int days) => today.subtract(Duration(days: days));

    return [
      AppUser(id: 'u1', name: 'Alex Admin', email: 'alex.admin@demopharmacy.example', phone: '+254700000201', role: UserRole.admin, isActive: true, lastSignInAt: ago(0)),
      AppUser(id: 'u2', name: 'Pat Pharmacist', email: 'pat.pharmacist@demopharmacy.example', phone: '+254700000202', role: UserRole.pharmacist, isActive: true, lastSignInAt: ago(1)),
      AppUser(id: 'u3', name: 'Casey Cashier', email: 'casey.cashier@demopharmacy.example', phone: '', role: UserRole.cashier, isActive: true, lastSignInAt: ago(0)),
      AppUser(id: 'u4', name: 'Sam Former', email: 'sam.former@demopharmacy.example', phone: '', role: UserRole.cashier, isActive: false, lastSignInAt: ago(120)),
    ];
  }
}
