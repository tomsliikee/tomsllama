import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/app_theme.dart';
import 'package:tomsllama/core/theme/pond_dark_theme.dart';

void main() {
  group('Theme Tests', () {
    test('All theme types return valid ThemeData with extensions', () {
      for (final type in AppThemeType.values) {
        final theme = getThemeData(type);
        expect(theme, isNotNull);
        final extension = theme.extension<AppThemeExtension>();
        expect(extension, isNotNull);
        expect(extension!.background, isNotNull);
        expect(extension.surface, isNotNull);
        expect(extension.accent, isNotNull);
      }
    });

    test('Pond Dark theme has dark brightness and mineral teal accents', () {
      expect(pondDarkTheme.brightness, Brightness.dark);
      final ext = pondDarkTheme.extension<AppThemeExtension>()!;
      expect(ext.background, isNotNull);
      expect(ext.accent, isNotNull);
    });

    test('getThemeData removes borders when isWallpaper is true', () {
      final themeWithWallpaper = getThemeData(AppThemeType.claude, isWallpaper: true);
      final ext = themeWithWallpaper.extension<AppThemeExtension>()!;
      expect(ext.isWallpaper, isTrue);
      expect(ext.border, Colors.transparent);
      expect(ext.borderSubtle, Colors.transparent);

      final themeWithoutWallpaper = getThemeData(AppThemeType.claude, isWallpaper: false);
      final extNoWp = themeWithoutWallpaper.extension<AppThemeExtension>()!;
      expect(extNoWp.isWallpaper, isFalse);
      expect(extNoWp.border, isNot(Colors.transparent));
    });
  });
}
