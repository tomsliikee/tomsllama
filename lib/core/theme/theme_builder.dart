import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';
import '../constants/app_typography.dart';
import 'app_theme.dart';

/// Builds a theme from a palette. The four themes differ only in colour; the
/// component styling below is what keeps stock Material looks (ink ripples,
/// grey tooltips, fat scrollbars, blue selection) out of all of them.
ThemeData buildAppTheme(Brightness brightness, AppThemeExtension colors) {
  final base = brightness == Brightness.dark ? const ColorScheme.dark() : const ColorScheme.light();

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    primaryColor: colors.accent,
    colorScheme: base.copyWith(
      primary: colors.accent,
      surface: colors.background,
      onSurface: colors.textPrimary,
    ),
    dividerColor: colors.border,
    fontFamily: AppTypography.serifFamily,

    // Feedback comes from Pressable; Material's ripple would double it.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: colors.hover,

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accent.withValues(alpha: 0.22),
      selectionHandleColor: colors.accent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
      verticalOffset: 16.0,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: colors.border, width: 1.0),
        boxShadow: AppElevation.floating(brightness),
      ),
      textStyle: AppTypography.label.copyWith(color: colors.textPrimary, fontSize: 11.0),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(5.0),
      radius: const Radius.circular(AppRadii.pill),
      crossAxisMargin: 3.0,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => colors.textSecondary.withValues(
          alpha: states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged) ? 0.45 : 0.22,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: BorderSide(color: colors.border, width: 1.0),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[colors],
  );
}
