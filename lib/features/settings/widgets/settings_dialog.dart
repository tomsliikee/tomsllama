import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
// Note: We would have a real settings service/riverpod provider here.
// For now, we mock the UI.

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final TextEditingController _urlController = TextEditingController(text: 'http://localhost:11434');
  final TextEditingController _personaController = TextEditingController(text: 'You are a highly capable AI assistant...');
  
  // 0=Claude, 1=Pond, 2=Dark
  int _selectedThemeIndex = 0;

  @override
  void dispose() {
    _urlController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Dialog(
      backgroundColor: appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: AppTypography.headline.copyWith(color: appColors.textPrimary, fontSize: 20.0)),
            const SizedBox(height: 24.0),
            
            Expanded(
              child: ListView(
                children: [
                  _buildSectionTitle('Theme', appColors),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      _buildThemeOption(0, 'Claude (Alabaster)', appColors),
                      const SizedBox(width: 12.0),
                      _buildThemeOption(1, 'Pond (Mint)', appColors),
                      const SizedBox(width: 12.0),
                      _buildThemeOption(2, 'Dark (Carbon)', appColors),
                    ],
                  ),
                  
                  const SizedBox(height: 24.0),
                  _buildSectionTitle('Ollama API URL', appColors),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _urlController,
                    style: AppTypography.uiControl.copyWith(color: appColors.textPrimary),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderSide: BorderSide(color: appColors.border)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: appColors.border)),
                      isDense: true,
                    ),
                  ),
                  
                  const SizedBox(height: 24.0),
                  _buildSectionTitle('Default Persona', appColors),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _personaController,
                    maxLines: 4,
                    style: AppTypography.body.copyWith(color: appColors.textPrimary),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderSide: BorderSide(color: appColors.border)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: appColors.border)),
                    ),
                  ),
                ],
              ),
            ),
            
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  // Save settings logic here
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.textPrimary,
                  foregroundColor: appColors.background,
                ),
                child: const Text('Save & Close'),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildThemeOption(int index, String label, AppThemeExtension appColors) {
    final isSelected = _selectedThemeIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedThemeIndex = index);
        // Call ref.read(themeProvider.notifier).setTheme(ThemeType.values[index]) in real app
      },
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? appColors.accent : appColors.border, width: 2.0),
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
