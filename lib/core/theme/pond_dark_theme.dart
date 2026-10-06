import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';
import 'theme_builder.dart';

final ThemeData pondDarkTheme = buildAppTheme(
  Brightness.dark,
  const AppThemeExtension(
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
);
