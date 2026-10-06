import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';
import '../constants/app_typography.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// The pill used for every small action and chip: an optional line icon and a
/// mono label on a hairline capsule that warms to the accent on hover.
class AppPill extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Widget? leading;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Shown in the accent colour, for a confirmed or selected state.
  final bool isActive;

  /// Fill at rest; defaults to the page background.
  final Color? fill;

  const AppPill({
    super.key,
    this.label,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.onTap,
    this.tooltip,
    this.isActive = false,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Pressable(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, isHovered, _) {
        final highlighted = isHovered || isActive;
        final foreground = highlighted ? colors.accent : colors.textSecondary;

        return AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: 28.0,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 7.0 : 11.0),
          decoration: BoxDecoration(
            color: isHovered ? colors.accentSubtle : (fill ?? colors.background),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: isHovered ? colors.accent.withValues(alpha: 0.35) : colors.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6.0)],
              if (icon != null) Icon(icon, size: 14.0, color: foreground),
              if (icon != null && label != null) const SizedBox(width: 6.0),
              if (label != null)
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: highlighted ? colors.accent : colors.textPrimary,
                    ),
                  ),
                ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 5.0),
                Icon(trailingIcon, size: 11.0, color: foreground),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A bare icon that gains a soft square of tint under the pointer.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? hoverColor;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 15.0,
    this.color,
    this.hoverColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Pressable(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, isHovered, _) => AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: const EdgeInsets.all(5.0),
        decoration: BoxDecoration(
          color: isHovered ? colors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Icon(
          icon,
          size: size,
          color: isHovered ? (hoverColor ?? colors.textPrimary) : (color ?? colors.textSecondary),
        ),
      ),
    );
  }
}
