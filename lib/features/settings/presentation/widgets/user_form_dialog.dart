import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_user.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';

/// Add or edit a user. Stays open and shows the message if saving fails
/// (a duplicate email, or removing the last admin).
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, this.existing});

  final AppUser? existing;

  static Future<void> show(BuildContext context, {AppUser? existing}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserFormDialog(existing: existing),
    );
  }

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.existing?.email ?? '');
  late final TextEditingController _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late UserRole _role = widget.existing?.role ?? UserRole.cashier;
  bool _saving = false;
  String? _error;
  String? _invitationToken;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = UserDraft(name: _name.text, email: _email.text, phone: _phone.text, role: _role);
    String? invitation;
    final error = await context.read<SettingsCubit>().saveUser(
          draft,
          id: widget.existing?.id,
          onInvitation: (token) => invitation = token,
        );
    if (!mounted) return;
    if (error == null) {
      if (invitation == null) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _invitationToken = invitation;
          _saving = false;
        });
      }
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;

    return AlertDialog(
      title: Text(editing ? SettingsStrings.editUser : SettingsStrings.addUser),
      content: SizedBox(
        width: SettingsLayout.userDialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_invitationToken != null) ...[
                const Text('User created. Share this one-time invitation token securely:'),
                const SizedBox(height: AppDimens.spaceMd),
                SelectableText(_invitationToken!, style: theme.textTheme.bodyMedium),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _invitationToken!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invitation token copied.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy token'),
                  ),
                ),
                const Text('The user can accept it at /api/v1/auth/accept-invitation.'),
              ] else ...[
                TextField(
                  controller: _name,
                  enabled: !_saving,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: SettingsStrings.fieldUserName),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: _email,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: SettingsStrings.fieldUserEmail,
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
                  decoration: const InputDecoration(
                    labelText: SettingsStrings.fieldUserPhone,
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                DropdownButtonFormField<UserRole>(
                  value: _role,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: SettingsStrings.fieldUserRole,
                    helperText: SettingsStrings.roleSummary(_role),
                    helperMaxLines: 3,
                  ),
                  items: [
                    for (final role in UserRole.values)
                      DropdownMenuItem(value: role, child: Text(SettingsStrings.roleLabel(role))),
                  ],
                  onChanged: _saving
                      ? null
                      : (role) {
                          if (role != null) setState(() => _role = role);
                        },
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                  child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.dangerFg)),
                ),
              if (!editing)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                  child: Text(
                    SettingsStrings.inviteNote,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (_invitationToken != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          )
        else ...[
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text(SettingsStrings.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? SettingsStrings.saving : SettingsStrings.save),
          ),
        ],
      ],
    );
  }
}
