import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  File? _settingsFile;

  Future<File> _getFile() async {
    if (_settingsFile != null) return _settingsFile!;
    final dir = await getApplicationDocumentsDirectory();
    final settingsPath = p.join(dir.path, 'tomsllama', 'settings.json');
    final file = File(settingsPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    _settingsFile = file;
    return file;
  }

  Future<AppThemeType> loadTheme() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        final themeName = map['theme'] as String?;
        if (themeName != null) {
          return AppThemeType.values.firstWhere(
            (e) => e.name == themeName,
            orElse: () => AppThemeType.claude,
          );
        }
      }
    } catch (_) {}
    return AppThemeType.claude;
  }

  Future<void> saveTheme(AppThemeType theme) async {
    try {
      final file = await _getFile();
      Map<String, dynamic> map = {};
      if (await file.exists()) {
        try {
          map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }
      map['theme'] = theme.name;
      await file.writeAsString(jsonEncode(map));
    } catch (_) {}
  }
}
