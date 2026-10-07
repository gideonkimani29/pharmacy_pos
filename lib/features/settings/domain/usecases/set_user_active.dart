import '../../../../core/result/result.dart';
import '../entities/app_user.dart';
import '../repositories/user_repository.dart';

class SetUserActive {
  const SetUserActive(this._repository);

  final UserRepository _repository;

  Future<Result<AppUser>> call(String id, {required bool active}) => _repository.setActive(id, active: active);
}
