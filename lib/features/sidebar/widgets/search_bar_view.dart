import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/services/localization_service.dart';

class SearchBarView extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const SearchBarView({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    // Same pill geometry as the mode slider it sits under.
    return Container(
      height: 32.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(AppIcons.search, size: 14.0, color: appColors.textSecondary),
          const SizedBox(width: 6.0),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.small.copyWith(color: appColors.textPrimary, height: 1.2),
              decoration: InputDecoration(
                hintText: I18n.searchChats,
                hintStyle: AppTypography.small.copyWith(
                  color: appColors.textSecondary.withValues(alpha: 0.8),
                  height: 1.2,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(8.0),
              child: Icon(AppIcons.close, size: 14.0, color: appColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
