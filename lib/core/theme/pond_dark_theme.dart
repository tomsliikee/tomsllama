import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';

final ThemeData pondDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.pondDarkBackground,
  primaryColor: AppColors.pondDarkAccent,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.pondDarkAccent,
    surface: AppColors.pondDarkBackground,
  ),
  dividerColor: AppColors.pondDarkBorder,
  fontFamily: 'Inter',
  extensions: const <ThemeExtension<dynamic>>[
    AppThemeExtension(
      background: AppColors.pondDarkBackground,
      sidebar: AppColors.pondDarkSidebar,
      surface: AppColors.pondDarkSurface,
      textPrimary: AppColors.pondDarkTextPrimary,
      textSecondary: AppColors.pondDarkTextSecondary,
      border: AppColors.pondDarkBorder,
      borderSubtle: AppColors.pondDarkBorderSubtle,
      accent: AppColors.pondDarkAccent,
      accentSubtle: AppColors.pondDarkAccentSubtle,
      codeBackground: AppColors.pondDarkCodeBackground,
      hover: AppColors.pondDarkHover,
    ),
  ],
);
