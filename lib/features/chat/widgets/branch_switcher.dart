import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';

class BranchSwitcher extends StatelessWidget {
  final int currentIndex;
  final int totalBranches;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const BranchSwitcher({
    super.key,
    required this.currentIndex,
    required this.totalBranches,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalBranches <= 1) return const SizedBox.shrink();

    final appColors = context.appColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left,
          onTap: currentIndex > 0 ? onPrevious : null,
          appColors: appColors,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '${currentIndex + 1} / $totalBranches',
            style: AppTypography.uiControl.copyWith(
              color: appColors.textSecondary,
              fontSize: 12.0,
            ),
          ),
        ),
        _ArrowButton(
          icon: Icons.chevron_right,
          onTap: currentIndex < totalBranches - 1 ? onNext : null,
          appColors: appColors,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final AppThemeExtension appColors;

  const _ArrowButton({
    required this.icon,
    this.onTap,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4.0),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Icon(
          icon,
          size: 16.0,
          color: disabled ? appColors.border : appColors.textSecondary,
        ),
      ),
    );
  }
}
