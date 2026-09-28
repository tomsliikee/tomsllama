import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';

final ThemeData pondTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.pondBackground,
  primaryColor: AppColors.pondAccent,
  colorScheme: const ColorScheme.light(
    primary: AppColors.pondAccent,
    surface: AppColors.pondBackground,
  ),
  dividerColor: AppColors.pondBorder,
  fontFamily: 'Inter',
  extensions: const <ThemeExtension<dynamic>>[
    AppThemeExtension(
      background: AppColors.pondBackground,
      sidebar: AppColors.pondSidebar,
      surface: AppColors.pondSurface,
      textPrimary: AppColors.pondTextPrimary,
      textSecondary: AppColors.pondTextSecondary,
      border: AppColors.pondBorder,
      borderSubtle: AppColors.pondBorderSubtle,
      accent: AppColors.pondAccent,
      accentSubtle: AppColors.pondAccentSubtle,
      codeBackground: AppColors.pondCodeBackground,
      hover: AppColors.pondHover,
    ),
  ],
);
