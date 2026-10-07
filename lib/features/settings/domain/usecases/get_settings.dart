import '../../../../core/result/result.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

class GetSettings {
  const GetSettings(this._repository);

  final SettingsRepository _repository;

  Future<Result<AppSettings>> call() => _repository.load();
}
