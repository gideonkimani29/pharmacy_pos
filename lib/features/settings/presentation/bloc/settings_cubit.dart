import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/get_users.dart';
import '../../domain/usecases/save_settings.dart';
import '../../domain/usecases/save_user.dart';
import '../../domain/usecases/set_user_active.dart';
import '../settings_constants.dart';

enum SettingsSection { pharmacy, sales, receipts, users }

enum SettingsStatus { loading, loaded, failure }

class SettingsNotice extends Equatable {
  const SettingsNotice({required this.id, required this.message});

  final int id;
  final String message;

  @override
  List<Object?> get props => [id, message];
}

class SettingsState extends Equatable {
  const SettingsState({
    this.section = SettingsSection.pharmacy,
    this.status = SettingsStatus.loading,
    this.saved,
    this.draft,
    this.saving = false,
    this.saveError,
    this.users = const [],
    this.formVersion = 0,
    this.failure,
    this.notice,
  });

  final SettingsSection section;
  final SettingsStatus status;

  /// What the server holds.
  final AppSettings? saved;

  /// What the forms show. Differs from [saved] while there are unsaved edits.
  final AppSettings? draft;
  final bool saving;
  final String? saveError;
  final List<AppUser> users;

  /// Bumped whenever the forms must rebuild from [draft] (load, save, discard).
  final int formVersion;
  final Failure? failure;
  final SettingsNotice? notice;

  bool get isDirty => draft != null && draft != saved;

  SettingsState copyWith({
    SettingsSection? section,
    SettingsStatus? status,
    AppSettings? saved,
    AppSettings? draft,
    bool? saving,
    String? saveError,
    bool clearSaveError = false,
    List<AppUser>? users,
    int? formVersion,
    Failure? failure,
    SettingsNotice? notice,
  }) {
    return SettingsState(
      section: section ?? this.section,
      status: status ?? this.status,
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      saving: saving ?? this.saving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
      users: users ?? this.users,
      formVersion: formVersion ?? this.formVersion,
      failure: failure ?? this.failure,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props =>
      [section, status, saved, draft, saving, saveError, users, formVersion, failure, notice];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required GetSettings getSettings,
    required SaveSettings saveSettings,
    required GetUsers getUsers,
    required SaveUser saveUser,
    required SetUserActive setUserActive,
  })  : _getSettings = getSettings,
        _saveSettings = saveSettings,
        _getUsers = getUsers,
        _saveUser = saveUser,
        _setUserActive = setUserActive,
        super(const SettingsState());

  final GetSettings _getSettings;
  final SaveSettings _saveSettings;
  final GetUsers _getUsers;
  final SaveUser _saveUser;
  final SetUserActive _setUserActive;
  int _noticeSequence = 0;

  static List<AppUser> _sorted(Iterable<AppUser> users) =>
      users.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _notify(String message) {
    emit(state.copyWith(notice: SettingsNotice(id: ++_noticeSequence, message: message)));
  }

  /// Loads settings and users in parallel. Discards unsaved edits.
  Future<void> load() async {
    emit(state.copyWith(status: SettingsStatus.loading));

    final settingsFuture = _getSettings();
    final usersFuture = _getUsers();
    final settings = await settingsFuture;
    final users = await usersFuture;
    if (isClosed) return;

    Failure? failure;
    if (settings is Err<AppSettings>) {
      failure = settings.failure;
    } else if (users is Err<List<AppUser>>) {
      failure = users.failure;
    }
    if (failure != null) {
      emit(state.copyWith(status: SettingsStatus.failure, failure: failure));
      return;
    }

    final loaded = (settings as Ok<AppSettings>).value;
    emit(state.copyWith(
      status: SettingsStatus.loaded,
      saved: loaded,
      draft: loaded,
      users: _sorted((users as Ok<List<AppUser>>).value),
      formVersion: state.formVersion + 1,
      clearSaveError: true,
    ));
  }

  void setSection(SettingsSection section) => emit(state.copyWith(section: section));

  void edit(AppSettings Function(AppSettings current) change) {
    final current = state.draft;
    if (current == null) return;
    emit(state.copyWith(draft: change(current), clearSaveError: true));
  }

  void discard() {
    emit(state.copyWith(draft: state.saved, formVersion: state.formVersion + 1, clearSaveError: true));
  }

  Future<void> save() async {
    final draft = state.draft;
    if (draft == null || !state.isDirty || state.saving) return;

    emit(state.copyWith(saving: true, clearSaveError: true));
    final result = await _saveSettings(draft);
    if (isClosed) return;
    switch (result) {
      case Ok<AppSettings>(:final value):
        emit(state.copyWith(
          saving: false,
          saved: value,
          draft: value,
          formVersion: state.formVersion + 1,
        ));
        _notify(SettingsStrings.saved);
      case Err<AppSettings>(:final failure):
        emit(state.copyWith(saving: false, saveError: failure.message));
    }
  }

  /// Returns null on success, or the message to show in the dialog.
  Future<String?> saveUser(UserDraft draft, {String? id}) async {
    final result = await _saveUser(draft, id: id);
    switch (result) {
      case Ok<AppUser>(:final value):
        final others = state.users.where((u) => u.id != value.id);
        emit(state.copyWith(users: _sorted([...others, value])));
        _notify(SettingsStrings.userSaved(value.name));
        return null;
      case Err<AppUser>(:final failure):
        return failure.message;
    }
  }

  Future<void> toggleUserActive(AppUser user) async {
    final result = await _setUserActive(user.id, active: !user.isActive);
    switch (result) {
      case Ok<AppUser>(:final value):
        emit(state.copyWith(users: _sorted(state.users.map((u) => u.id == value.id ? value : u))));
        _notify(value.isActive
            ? SettingsStrings.userActivated(value.name)
            : SettingsStrings.userDeactivated(value.name));
      case Err<AppUser>(:final failure):
        _notify(failure.message);
    }
  }
}
