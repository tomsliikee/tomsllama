import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  primaryColor: AppColors.darkAccent,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.darkAccent,
    surface: AppColors.darkBackground,
  ),
  dividerColor: AppColors.darkBorder,
  fontFamily: 'Inter',
  extensions: const <ThemeExtension<dynamic>>[
    AppThemeExtension(
      background: AppColors.darkBackground,
      sidebar: AppColors.darkSidebar,
      surface: AppColors.darkSurface,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      border: AppColors.darkBorder,
      borderSubtle: AppColors.darkBorderSubtle,
      accent: AppColors.darkAccent,
      accentSubtle: AppColors.darkAccentSubtle,
      codeBackground: AppColors.darkCodeBackground,
      hover: AppColors.darkHover,
    ),
  ],
);
