import '../../../../core/result/result.dart';
import '../entities/app_user.dart';

abstract interface class UserRepository {
  Future<Result<List<AppUser>>> list();

  /// Creates the user and returns a one-time invitation token when available.
  Future<Result<AppUser>> create(UserDraft draft);
  Future<Result<AppUser>> update(String id, UserDraft draft);
  Future<Result<AppUser>> setActive(String id, {required bool active});
}
