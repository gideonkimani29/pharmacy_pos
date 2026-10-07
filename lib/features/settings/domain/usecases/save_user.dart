import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../contact_validation.dart';
import '../entities/app_user.dart';
import '../repositories/user_repository.dart';
import '../settings_messages.dart';

/// Creates a user, or updates one when [id] is given. The backend enforces
/// unique emails and the "at least one active admin" rule.
class SaveUser {
  const SaveUser(this._repository);

  final UserRepository _repository;

  Future<Result<AppUser>> call(UserDraft draft, {String? id}) {
    final failure = _validate(draft);
    if (failure != null) return Future.value(Err<AppUser>(failure));

    final clean = UserDraft(
      name: draft.name.trim(),
      email: draft.email.trim().toLowerCase(),
      phone: ContactValidation.normalizePhone(draft.phone),
      role: draft.role,
    );
    return id == null ? _repository.create(clean) : _repository.update(id, clean);
  }

  Failure? _validate(UserDraft draft) {
    if (draft.name.trim().isEmpty) return const ValidationFailure(SettingsMessages.userNameMissing);

    final email = draft.email.trim();
    if (email.isEmpty) return const ValidationFailure(SettingsMessages.userEmailMissing);
    if (!ContactValidation.isValidEmail(email)) return const ValidationFailure(SettingsMessages.emailInvalid);

    final phone = draft.phone.trim();
    if (phone.isNotEmpty && !ContactValidation.isValidPhone(phone)) {
      return const ValidationFailure(SettingsMessages.phoneInvalid);
    }
    return null;
  }
}
