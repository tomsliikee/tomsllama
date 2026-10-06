import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/services/localization_service.dart';

class NewWorkspaceDialog extends StatefulWidget {
  const NewWorkspaceDialog({super.key});

  @override
  State<NewWorkspaceDialog> createState() => _NewWorkspaceDialogState();
}

class _NewWorkspaceDialogState extends State<NewWorkspaceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop({
      'name': name,
      'prompt': _promptController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return AppDialog(
      title: I18n.newWorkspaceTitle,
      width: 480.0,
      leading: Icon(AppIcons.workspace, size: 20.0, color: appColors.accent),
      actions: [
        AppButton(label: I18n.cancel, onTap: () => Navigator.of(context).pop()),
        AppButton(label: I18n.create, isPrimary: true, onTap: _submit),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFieldLabel(I18n.workspaceNameLabel),
          const SizedBox(height: AppSpace.s),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: AppTypography.small.copyWith(color: appColors.textPrimary),
            decoration: appInputDecoration(context, hint: I18n.workspaceNameHint),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpace.l + 4.0),
          AppFieldLabel(I18n.workspacePromptTitle),
          const SizedBox(height: AppSpace.s),
          TextField(
            controller: _promptController,
            minLines: 3,
            maxLines: 5,
            style: AppTypography.small.copyWith(color: appColors.textPrimary, height: 1.45),
            decoration: appInputDecoration(
              context,
              hint: I18n.isGerman
                  ? 'Systemanweisungen für alle Chats in diesem Workspace...'
                  : 'System instructions for all chats in this workspace...',
            ),
          ),
        ],
      ),
    );
  }
}
