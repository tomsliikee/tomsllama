import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';
import 'theme_builder.dart';

final ThemeData pondTheme = buildAppTheme(
  Brightness.light,
  const AppThemeExtension(
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
);
