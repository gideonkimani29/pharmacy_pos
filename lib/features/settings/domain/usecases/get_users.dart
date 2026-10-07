import '../../../../core/result/result.dart';
import '../entities/app_user.dart';
import '../repositories/user_repository.dart';

class GetUsers {
  const GetUsers(this._repository);

  final UserRepository _repository;

  Future<Result<List<AppUser>>> call() => _repository.list();
}
