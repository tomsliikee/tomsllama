import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/frosted_glass.dart';
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

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480.0),
        child: FrostedGlass(
          borderRadius: BorderRadius.circular(16.0),
          borderColor: appColors.borderSubtle,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Title
              Row(
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: appColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.workspaces_outlined, size: 18.0, color: appColors.accent),
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    I18n.newWorkspace,
                    style: AppTypography.headline.copyWith(
                      color: appColors.textPrimary,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),

              // Name Input Label
              Text(
                I18n.workspaceNameLabel.toUpperCase(),
                style: AppTypography.uiControl.copyWith(
                  color: appColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6.0),
              Container(
                decoration: BoxDecoration(
                  color: appColors.background,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: appColors.borderSubtle, width: 1.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: AppTypography.body.copyWith(color: appColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: I18n.workspaceNameHint,
                    hintStyle: AppTypography.body.copyWith(color: appColors.textSecondary.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 16.0),

              // Workspace Prompt Label (Optional)
              Text(
                I18n.workspacePromptTitle,
                style: AppTypography.uiControl.copyWith(
                  color: appColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6.0),
              Container(
                decoration: BoxDecoration(
                  color: appColors.background,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: appColors.borderSubtle, width: 1.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: TextField(
                  controller: _promptController,
                  minLines: 2,
                  maxLines: 4,
                  style: AppTypography.body.copyWith(color: appColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: I18n.isGerman
                        ? 'Systemanweisungen für alle Chats in diesem Workspace...'
                        : 'System instructions for all chats in this workspace...',
                    hintStyle: AppTypography.body.copyWith(color: appColors.textSecondary.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // Action Buttons: Cancel and Create
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: appColors.textSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    ),
                    child: Text(I18n.cancel, style: AppTypography.uiControl),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                    child: Text(
                      I18n.create,
                      style: AppTypography.uiControl.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
