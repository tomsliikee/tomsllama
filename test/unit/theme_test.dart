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
  });
}
