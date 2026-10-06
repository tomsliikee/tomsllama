import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';
import 'theme_builder.dart';

final ThemeData darkTheme = buildAppTheme(
  Brightness.dark,
  const AppThemeExtension(
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
);
