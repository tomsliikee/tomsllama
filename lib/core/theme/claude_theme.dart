import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';
import 'theme_builder.dart';

final ThemeData claudeTheme = buildAppTheme(
  Brightness.light,
  const AppThemeExtension(
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
);
