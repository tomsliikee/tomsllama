import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';
import '../constants/app_typography.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// The frame every dialog shares: paper surface, hairline edge, the floating
/// shadow, a serif title and a row of actions bottom right.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget child;
  final List<Widget> actions;
  final double width;

  /// A fixed height makes [child] fill the space between title and actions;
  /// without one the dialog is as tall as its content.
  final double? height;

  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.actions = const [],
    this.width = 520.0,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: colors.border, width: 1.0),
            boxShadow: AppElevation.floating(Theme.of(context).brightness),
          ),
          child: Column(
            mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AppSpace.m)],
                  Expanded(
                    child: Text(title, style: AppTypography.title.copyWith(color: colors.textPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.l + 4.0),
              if (height == null) child else Expanded(child: child),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpace.l + 4.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpace.s),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary action is filled with the accent; the secondary is plain text.
/// A destructive action reads in the accent without a fill, so it never looks
/// like the default choice.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isDestructive;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onTap != null;

    return Pressable(
      onTap: onTap,
      builder: (context, isHovered, _) {
        final Color fill;
        final Color foreground;
        if (isPrimary) {
          fill = colors.accent.withValues(alpha: !enabled ? 0.4 : (isHovered ? 0.88 : 1.0));
          foreground = colors.surface;
        } else {
          fill = isHovered ? colors.hover : Colors.transparent;
          foreground = isDestructive ? colors.accent : (isHovered ? colors.textPrimary : colors.textSecondary);
        }

        return AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: 34.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(color: foreground, fontWeight: FontWeight.w500),
          ),
        );
      },
    );
  }
}

/// Tracked mono caption above a form field or section.
class AppFieldLabel extends StatelessWidget {
  final String text;

  const AppFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.micro.copyWith(color: context.appColors.textSecondary),
    );
  }
}

/// One look for every text field: paper-coloured well, hairline, accent on focus.
InputDecoration appInputDecoration(BuildContext context, {String? hint, Widget? prefixIcon, bool mono = false}) {
  final colors = context.appColors;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: color, width: 1.0),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: (mono ? AppTypography.code : AppTypography.small).copyWith(
      color: colors.textSecondary.withValues(alpha: 0.7),
    ),
    prefixIcon: prefixIcon,
    prefixIconConstraints: const BoxConstraints(minWidth: 38.0, minHeight: 0.0),
    filled: true,
    fillColor: colors.background,
    hoverColor: Colors.transparent,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
    border: border(colors.border),
    enabledBorder: border(colors.border),
    disabledBorder: border(colors.borderSubtle),
    focusedBorder: border(colors.accent.withValues(alpha: 0.7)),
  );
}
