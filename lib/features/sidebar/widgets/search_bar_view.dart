import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: appColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16.0, color: appColors.textSecondary),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.uiControl.copyWith(color: appColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: AppTypography.uiControl.copyWith(color: appColors.textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: onClear,
              child: Icon(Icons.close, size: 16.0, color: appColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
