import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/services/settings_service.dart';
import '../../models/controllers/model_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _instructionsController;
  String? _defaultModel;
  late bool _closeToTray;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _urlController = TextEditingController(text: settings.ollamaUrl);
    _instructionsController = TextEditingController(text: settings.customInstructions);
    _defaultModel = settings.defaultModel;
    _closeToTray = settings.closeToTray;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    final previous = ref.read(appSettingsProvider);
    final url = _urlController.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final settings = AppSettings(
      ollamaUrl: url.isEmpty ? AppSettings.defaultOllamaUrl : url,
      defaultModel: _defaultModel,
      customInstructions: _instructionsController.text.trim(),
      closeToTray: _closeToTray,
    );

    await ref.read(appSettingsProvider.notifier).save(settings);
    // A different host has a different set of models.
    if (settings.ollamaUrl != previous.ollamaUrl) {
      ref.read(modelProvider.notifier).loadModels();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final currentTheme = ref.watch(themeProvider);
    final models = ref.watch(modelProvider).models;

    // Keep a configured model selectable even while its host is unreachable.
    final modelNames = [
      ...models.map((m) => m.name),
      if (_defaultModel != null && !models.any((m) => m.name == _defaultModel)) _defaultModel!,
    ];

    return AppDialog(
      title: I18n.settingsTitle,
      width: 580.0,
      height: 580.0,
      actions: [
        AppButton(label: I18n.cancel, onTap: () => Navigator.of(context).pop()),
        AppButton(label: I18n.saveAndClose, isPrimary: true, onTap: _saveAndClose),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFieldLabel(I18n.theme),
            const SizedBox(height: AppSpace.s),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              children: [
                _buildThemeOption(AppThemeType.claude, I18n.themeClaudeAlabaster, currentTheme),
                _buildThemeOption(AppThemeType.pond, I18n.themePondMint, currentTheme),
                _buildThemeOption(AppThemeType.dark, I18n.themeDarkCarbon, currentTheme),
                _buildThemeOption(AppThemeType.pondDark, I18n.themePondDarkMineral, currentTheme),
              ],
            ),

            const SizedBox(height: AppSpace.xl),
            AppFieldLabel(I18n.ollamaApiUrl),
            const SizedBox(height: AppSpace.s),
            TextField(
              key: const Key('settings_ollama_url'),
              controller: _urlController,
              style: AppTypography.code.copyWith(color: appColors.textPrimary),
              decoration: appInputDecoration(context, hint: AppSettings.defaultOllamaUrl, mono: true),
            ),

            const SizedBox(height: AppSpace.xl),
            AppFieldLabel(I18n.defaultModel),
            const SizedBox(height: AppSpace.s),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: appColors.background,
                border: Border.all(color: appColors.border),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _defaultModel,
                  isExpanded: true,
                  isDense: true,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  dropdownColor: appColors.surface,
                  icon: Icon(AppIcons.caretDown, size: 13.0, color: appColors.textSecondary),
                  padding: const EdgeInsets.symmetric(vertical: 11.0),
                  style: AppTypography.code.copyWith(color: appColors.textPrimary),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        I18n.defaultModelAutomatic,
                        style: AppTypography.small.copyWith(
                          color: appColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    for (final name in modelNames) DropdownMenuItem<String?>(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setState(() => _defaultModel = value),
                ),
              ),
            ),

            const SizedBox(height: AppSpace.xl),
            AppFieldLabel(I18n.customInstructions),
            const SizedBox(height: AppSpace.xs),
            Text(
              I18n.customInstructionsHint,
              style: AppTypography.small.copyWith(color: appColors.textSecondary, fontSize: 14.0),
            ),
            const SizedBox(height: AppSpace.s),
            TextField(
              key: const Key('settings_custom_instructions'),
              controller: _instructionsController,
              maxLines: 4,
              style: AppTypography.small.copyWith(color: appColors.textPrimary, height: 1.45),
              decoration: appInputDecoration(context),
            ),

            const SizedBox(height: AppSpace.xl),
            Pressable(
              onTap: () => setState(() => _closeToTray = !_closeToTray),
              builder: (context, isHovered, _) => Row(
                children: [
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 16.0,
                    height: 16.0,
                    decoration: BoxDecoration(
                      color: _closeToTray ? appColors.accent : appColors.background,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(
                        color: _closeToTray || isHovered ? appColors.accent : appColors.border,
                      ),
                    ),
                    child: _closeToTray ? Icon(AppIcons.check, size: 11.0, color: appColors.surface) : null,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      I18n.closeToTray,
                      style: AppTypography.small.copyWith(color: appColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The theme applies immediately, like the switcher in the header bar.
  Widget _buildThemeOption(AppThemeType type, String label, AppThemeType current) {
    return AppPill(
      label: label,
      isActive: current == type,
      onTap: () => ref.read(themeProvider.notifier).setTheme(type),
    );
  }
}
