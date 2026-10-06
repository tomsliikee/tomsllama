import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/core/services/ollama_service.dart';
import 'package:tomsllama/core/services/settings_service.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/settings/controllers/settings_controller.dart';
import 'package:tomsllama/features/settings/widgets/settings_dialog.dart';

void main() {
  testWidgets('SettingsDialog saves URL, instructions and tray behaviour', (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(() => OllamaService().baseUrl = AppSettings.defaultOllamaUrl);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: claudeTheme,
          home: const Scaffold(body: SettingsDialog()),
        ),
      ),
    );
    await tester.pump();

    final urlField = tester.widget<TextField>(find.byKey(const Key('settings_ollama_url')));
    expect(urlField.controller!.text, AppSettings.defaultOllamaUrl);

    await tester.enterText(find.byKey(const Key('settings_ollama_url')), 'http://192.168.1.20:11434/');
    await tester.enterText(find.byKey(const Key('settings_custom_instructions')), 'Antworte auf Deutsch.');
    await tester.ensureVisible(find.text(I18n.closeToTray));
    await tester.pump();
    await tester.tap(find.text(I18n.closeToTray));
    await tester.pump();

    await tester.tap(find.text(I18n.saveAndClose));
    await tester.pump();

    final saved = container.read(appSettingsProvider);
    expect(saved.ollamaUrl, 'http://192.168.1.20:11434');
    expect(saved.customInstructions, 'Antworte auf Deutsch.');
    expect(saved.closeToTray, isTrue);
    expect(OllamaService().baseUrl, 'http://192.168.1.20:11434');
  });
}
