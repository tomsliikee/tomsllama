import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';

final ThemeData claudeTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.claudeBackground,
  primaryColor: AppColors.claudeAccent,
  colorScheme: const ColorScheme.light(
    primary: AppColors.claudeAccent,
    surface: AppColors.claudeBackground,
  ),
  dividerColor: AppColors.claudeBorder,
  fontFamily: 'Inter',
  extensions: const <ThemeExtension<dynamic>>[
    AppThemeExtension(
      background: AppColors.claudeBackground,
      sidebar: AppColors.claudeSidebar,
      surface: AppColors.claudeSurface,
      textPrimary: AppColors.claudeTextPrimary,
      textSecondary: AppColors.claudeTextSecondary,
      border: AppColors.claudeBorder,
      borderSubtle: AppColors.claudeBorderSubtle,
      accent: AppColors.claudeAccent,
      accentSubtle: AppColors.claudeAccentSubtle,
      codeBackground: AppColors.claudeCodeBackground,
      hover: AppColors.claudeHover,
    ),
  ],
);
