import 'package:flutter/material.dart';
import '../../../core/models/ollama_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';

class ModelSelectorDropdown extends StatelessWidget {
  final List<OllamaModel> models;
  final String? selectedModel;
  final ValueChanged<String?> onChanged;
  final VoidCallback onManageModels;

  const ModelSelectorDropdown({
    super.key,
    required this.models,
    required this.selectedModel,
    required this.onChanged,
    required this.onManageModels,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    final itemNames = models.map((m) => m.name).toSet();
    final String? safeValue = (selectedModel != null && itemNames.contains(selectedModel))
        ? selectedModel
        : (models.isNotEmpty ? models.first.name : null);

    return Container(
      height: 36.0,
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: appColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          borderRadius: BorderRadius.circular(16.0),
          icon: Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: Icon(Icons.keyboard_arrow_down, size: 15.0, color: appColors.textSecondary),
          ),
          dropdownColor: appColors.surface,
          style: AppTypography.code.copyWith(
            color: appColors.textPrimary,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
          items: [
            if (models.isEmpty && safeValue == null)
              DropdownMenuItem<String>(
                value: null,
                enabled: false,
                child: Text(I18n.noModelsInstalled, style: TextStyle(color: appColors.textSecondary)),
              ),
            ...models.map((model) {
              return DropdownMenuItem<String>(
                value: model.name,
                child: Text(model.name),
              );
            }),
            DropdownMenuItem<String>(
              value: 'manage',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 14.0, color: appColors.textSecondary),
                  const SizedBox(width: 8.0),
                  Text(
                    I18n.manageModels,
                    style: AppTypography.uiControl.copyWith(
                      color: appColors.textSecondary,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == 'manage') {
              onManageModels();
            } else if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}
