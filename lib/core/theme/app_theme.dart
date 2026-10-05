import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';
import 'claude_theme.dart';
import 'pond_theme.dart';
import 'dark_theme.dart';
import 'pond_dark_theme.dart';

enum AppThemeType {
  claude,
  pond,
  dark,
  pondDark,
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color borderSubtle;
  final Color accent;
  final Color accentSubtle;
  final Color codeBackground;
  final Color hover;
  final bool isWallpaper;

  const AppThemeExtension({
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.borderSubtle,
    required this.accent,
    required this.accentSubtle,
    required this.codeBackground,
    required this.hover,
    this.isWallpaper = false,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? background,
    Color? sidebar,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? borderSubtle,
    Color? accent,
    Color? accentSubtle,
    Color? codeBackground,
    Color? hover,
    bool? isWallpaper,
  }) {
    return AppThemeExtension(
      background: background ?? this.background,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accent: accent ?? this.accent,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      codeBackground: codeBackground ?? this.codeBackground,
      hover: hover ?? this.hover,
      isWallpaper: isWallpaper ?? this.isWallpaper,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      isWallpaper: t < 0.5 ? isWallpaper : other.isWallpaper,
    );
  }
}

class ThemeNotifier extends Notifier<AppThemeType> {
  @override
  AppThemeType build() {
    _initPersistentTheme();
    return AppThemeType.claude;
  }

  void _initPersistentTheme() async {
    try {
      final saved = await SettingsService().loadTheme();
      if (state != saved) {
        state = saved;
      }
    } catch (_) {}
  }

  void setTheme(AppThemeType theme) {
    state = theme;
    SettingsService().saveTheme(theme);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeType>(() {
  return ThemeNotifier();
});

class WallpaperNotifier extends Notifier<bool> {
  @override
  bool build() {
    _init();
    return true;
  }

  Future<void> _init() async {
    final enabled = await SettingsService().loadWallpaperEnabled();
    state = enabled;
  }

  void setWallpaper(bool enabled) {
    state = enabled;
    SettingsService().saveWallpaperEnabled(enabled);
  }

  void toggle() {
    setWallpaper(!state);
  }
}

final wallpaperProvider = NotifierProvider<WallpaperNotifier, bool>(() {
  return WallpaperNotifier();
});

extension AppThemeExtensionProvider on BuildContext {
  AppThemeExtension get appColors => Theme.of(this).extension<AppThemeExtension>()!;
}

ThemeData getThemeData(AppThemeType type, {bool isWallpaper = false}) {
  ThemeData base;
  switch (type) {
    case AppThemeType.claude:
      base = claudeTheme;
      break;
    case AppThemeType.pond:
      base = pondTheme;
      break;
    case AppThemeType.dark:
      base = darkTheme;
      break;
    case AppThemeType.pondDark:
      base = pondDarkTheme;
      break;
  }

  final appColors = base.extension<AppThemeExtension>()!;
  final updatedColors = appColors.copyWith(
    isWallpaper: isWallpaper,
    border: isWallpaper ? Colors.transparent : appColors.border,
    borderSubtle: isWallpaper ? Colors.transparent : appColors.borderSubtle,
  );

  return base.copyWith(
    extensions: [updatedColors],
  );
}
