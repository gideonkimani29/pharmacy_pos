import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/settings_messages.dart';

class DemoUserRepository implements UserRepository {
  DemoUserRepository({List<AppUser> users = const []}) : _items = [...users];

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

}
