import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_cubit.dart';
import '../settings_constants.dart';

/// Titled white card that holds one group of fields.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: SettingsLayout.formMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceXs),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: AppDimens.spaceLg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays fields out two to a row, wrapping to one on narrow windows.
class SettingsFieldGrid extends StatelessWidget {
  const SettingsFieldGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.spaceLg,
      runSpacing: AppDimens.spaceLg,
      children: [
        for (final child in children) SizedBox(width: SettingsLayout.halfFieldWidth, child: child),
      ],
    );
  }
}

/// A text field that owns its controller. The section around it is rebuilt with
/// a new key whenever the form must reset, which gives a fresh controller.
class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onChanged,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixText,
  });

  final String initialValue;
  final String label;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final IconData? prefixIcon;
  final String? suffixText;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 3,
        suffixText: widget.suffixText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
      ),
    );
  }
}

class SettingsSwitchRow extends StatefulWidget {
  const SettingsSwitchRow({
    super.key,
    required this.initialValue,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  final bool initialValue;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  State<SettingsSwitchRow> createState() => _SettingsSwitchRowState();
}

class _SettingsSwitchRowState extends State<SettingsSwitchRow> {
  late bool _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      value: _value,
      onChanged: (value) {
        setState(() => _value = value);
        widget.onChanged(value);
      },
    );
  }
}

/// Information or warning strip inside a card.
class SettingsNote extends StatelessWidget {
  const SettingsNote({super.key, required this.message, this.warning = false});

  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final foreground = warning ? AppColors.warningFg : AppColors.infoFg;
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: warning ? AppColors.warningBg : AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warning ? Icons.info_outline : Icons.lock_outline, size: AppDimens.iconSm, color: foreground),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground)),
          ),
        ],
      ),
    );
  }
}

/// Save / discard strip pinned under the form sections.
class SettingsSaveBar extends StatelessWidget {
  const SettingsSaveBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<SettingsCubit>();

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) =>
          previous.isDirty != current.isDirty ||
          previous.saving != current.saving ||
          previous.saveError != current.saveError,
      builder: (context, state) {
        return Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.saveError ?? (state.isDirty ? SettingsStrings.unsavedChanges : ''),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: state.saveError != null ? AppColors.dangerFg : AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: state.isDirty && !state.saving ? cubit.discard : null,
                  child: const Text(SettingsStrings.discard),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                FilledButton(
                  onPressed: state.isDirty && !state.saving ? cubit.save : null,
                  child: Text(state.saving ? SettingsStrings.saving : SettingsStrings.save),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
