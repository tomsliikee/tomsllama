import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ollama_service.dart';
import '../../../core/services/settings_service.dart';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  // main() loads the settings before runApp, so the cached copy is normally
  // there and consumers never see defaults flash before the real values.
  AppSettingsNotifier() : super(SettingsService().cachedAppSettings ?? const AppSettings());

  Future<void> save(AppSettings settings) async {
    state = settings;
    OllamaService().baseUrl = settings.ollamaUrl;
    await SettingsService().saveAppSettings(settings);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
