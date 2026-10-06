import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';
import 'app_paths.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  File? _settingsFile;

  Future<File> _getFile() async {
    if (_settingsFile != null) return _settingsFile!;
    final dir = await appDataDirectory();
    final settingsPath = p.join(dir.path, 'settings.json');
    final file = File(settingsPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    _settingsFile = file;
    return file;
  }

  // Saves run one after another. Each one rewrites the whole file, so two
  // overlapping saves would otherwise drop each other's keys.
  Future<void> _writeQueue = Future<void>.value();

  Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _update(void Function(Map<String, dynamic> map) mutate) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _getFile();
        final map = await _read();
        mutate(map);
        await file.writeAsString(jsonEncode(map));
      } catch (_) {}
    });
    return _writeQueue;
  }

  /// Settings as last loaded or saved; lets startup code read them synchronously.
  AppSettings? cachedAppSettings;

  Future<AppSettings> loadAppSettings() async {
    final settings = AppSettings.fromJson(await _read());
    cachedAppSettings = settings;
    return settings;
  }

  Future<void> saveAppSettings(AppSettings settings) {
    cachedAppSettings = settings;
    return _update((map) => map.addAll(settings.toJson()));
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

  Future<void> saveTheme(AppThemeType theme) {
    return _update((map) => map['theme'] = theme.name);
  }

  Future<Map<String, dynamic>?> loadHardwareProfile() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['hardware_profile'] != null) {
          return map['hardware_profile'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveHardwareProfile({
    required double promptEvalSpeed,
    required double genSpeed,
    required int sampleCount,
    required String detectedDeviceType,
    Map<String, dynamic>? modelProfiles,
  }) {
    return _update((map) {
      map['hardware_profile'] = {
        'prompt_eval_speed': promptEvalSpeed,
        'gen_speed': genSpeed,
        'sample_count': sampleCount,
        'device_type': detectedDeviceType,
        if (modelProfiles != null) 'model_profiles': modelProfiles,
        'updated_at': DateTime.now().toIso8601String(),
      };
    });
  }

  Future<bool> loadComposerShelfExpanded() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        return map['composer_shelf_expanded'] as bool? ?? false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> saveComposerShelfExpanded(bool expanded) {
    return _update((map) => map['composer_shelf_expanded'] = expanded);
  }
}


class AppSettings {
  static const String defaultOllamaUrl = 'http://localhost:11434';

  final String ollamaUrl;

  /// Model selected on launch; null picks one automatically.
  final String? defaultModel;

  /// Instructions added to the system prompt of every chat, after the persona.
  final String customInstructions;

  /// Closing the window hides it to the tray instead of quitting.
  final bool closeToTray;

  /// Fold older turns into a summary when a chat nears its context window.
  final bool autoCompact;

  /// Context window to run chats in: null picks a small tier per turn,
  /// [modelMaxContext] uses whatever the model supports, any other value is a
  /// token count that is capped at the model's own limit.
  final int? contextWindow;
  static const int modelMaxContext = 0;

  const AppSettings({
    this.ollamaUrl = defaultOllamaUrl,
    this.defaultModel,
    this.customInstructions = '',
    this.closeToTray = false,
    this.autoCompact = true,
    this.contextWindow,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final url = (json['ollama_url'] as String?)?.trim() ?? '';
    final model = (json['default_model'] as String?)?.trim() ?? '';
    return AppSettings(
      ollamaUrl: url.isEmpty ? defaultOllamaUrl : url,
      defaultModel: model.isEmpty ? null : model,
      customInstructions: (json['custom_instructions'] as String?) ?? '',
      closeToTray: (json['close_to_tray'] as bool?) ?? false,
      autoCompact: (json['auto_compact'] as bool?) ?? true,
      contextWindow: json['context_window'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'ollama_url': ollamaUrl,
        'default_model': defaultModel,
        'custom_instructions': customInstructions,
        'close_to_tray': closeToTray,
        'auto_compact': autoCompact,
        'context_window': contextWindow,
      };
}
