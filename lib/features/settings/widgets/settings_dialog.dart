import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
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

    return Dialog(
      backgroundColor: appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        width: 600,
        height: 560,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.settingsTitle, style: AppTypography.headline.copyWith(color: appColors.textPrimary, fontSize: 20.0)),
            const SizedBox(height: 24.0),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle(I18n.theme, appColors),
                    const SizedBox(height: 8.0),
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 8.0,
                      children: [
                        _buildThemeOption(AppThemeType.claude, I18n.themeClaudeAlabaster, currentTheme, appColors),
                        _buildThemeOption(AppThemeType.pond, I18n.themePondMint, currentTheme, appColors),
                        _buildThemeOption(AppThemeType.dark, I18n.themeDarkCarbon, currentTheme, appColors),
                        _buildThemeOption(AppThemeType.pondDark, I18n.themePondDarkMineral, currentTheme, appColors),
                      ],
                    ),

                    const SizedBox(height: 24.0),
                    _buildSectionTitle(I18n.ollamaApiUrl, appColors),
                    const SizedBox(height: 8.0),
                    TextField(
                      key: const Key('settings_ollama_url'),
                      controller: _urlController,
                      style: AppTypography.code.copyWith(color: appColors.textPrimary),
                      decoration: _inputDecoration(appColors, hint: AppSettings.defaultOllamaUrl),
                    ),

                    const SizedBox(height: 24.0),
                    _buildSectionTitle(I18n.defaultModel, appColors),
                    const SizedBox(height: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: appColors.border),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _defaultModel,
                          isExpanded: true,
                          isDense: true,
                          dropdownColor: appColors.surface,
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          style: AppTypography.code.copyWith(color: appColors.textPrimary),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                I18n.defaultModelAutomatic,
                                style: AppTypography.uiControl.copyWith(color: appColors.textSecondary),
                              ),
                            ),
                            for (final name in modelNames) DropdownMenuItem<String?>(value: name, child: Text(name)),
                          ],
                          onChanged: (value) => setState(() => _defaultModel = value),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),
                    _buildSectionTitle(I18n.customInstructions, appColors),
                    const SizedBox(height: 4.0),
                    Text(
                      I18n.customInstructionsHint,
                      style: AppTypography.uiControl.copyWith(
                        color: appColors.textSecondary,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      key: const Key('settings_custom_instructions'),
                      controller: _instructionsController,
                      maxLines: 4,
                      style: AppTypography.uiControl.copyWith(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                      decoration: _inputDecoration(appColors),
                    ),

                    const SizedBox(height: 24.0),
                    InkWell(
                      onTap: () => setState(() => _closeToTray = !_closeToTray),
                      borderRadius: BorderRadius.circular(8.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 16.0,
                              height: 16.0,
                              decoration: BoxDecoration(
                                color: _closeToTray ? appColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(color: _closeToTray ? appColors.accent : appColors.border),
                              ),
                              child: _closeToTray
                                  ? Icon(Icons.check, size: 12.0, color: appColors.surface)
                                  : null,
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Text(
                                I18n.closeToTray,
                                style: AppTypography.uiControl.copyWith(color: appColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    I18n.cancel,
                    style: AppTypography.uiControl.copyWith(color: appColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _saveAndClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.textPrimary,
                    foregroundColor: appColors.background,
                    elevation: 0,
                  ),
                  child: Text(I18n.saveAndClose),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(AppThemeExtension appColors, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.code.copyWith(color: appColors.textSecondary.withValues(alpha: 0.6)),
      border: OutlineInputBorder(borderSide: BorderSide(color: appColors.border)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: appColors.border)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: appColors.accent)),
      isDense: true,
    );
  }

  Widget _buildSectionTitle(String title, AppThemeExtension appColors) {
    return Text(
      title,
      style: AppTypography.uiControl.copyWith(
        color: appColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // The theme applies immediately, like the switcher in the header bar.
  Widget _buildThemeOption(AppThemeType type, String label, AppThemeType current, AppThemeExtension appColors) {
    final isSelected = current == type;
    return InkWell(
      onTap: () => ref.read(themeProvider.notifier).setTheme(type),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? appColors.accent : appColors.border, width: 1.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          label,
          style: AppTypography.uiControl.copyWith(
            color: isSelected ? appColors.textPrimary : appColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
