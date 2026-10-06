import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
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
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: appColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 14.0, color: appColors.textSecondary),
          const SizedBox(width: 6.0),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.uiControl.copyWith(color: appColors.textPrimary, fontSize: 12.0),
              decoration: InputDecoration(
                hintText: I18n.searchChats,
                hintStyle: AppTypography.uiControl.copyWith(
                  color: appColors.textSecondary,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
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
              child: Icon(Icons.close, size: 14.0, color: appColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
