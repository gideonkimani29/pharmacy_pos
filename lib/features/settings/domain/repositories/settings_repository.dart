import '../../../../core/result/result.dart';
import '../entities/app_settings.dart';

abstract interface class SettingsRepository {
  Future<Result<AppSettings>> load();
  Future<Result<AppSettings>> save(AppSettings settings);
}
