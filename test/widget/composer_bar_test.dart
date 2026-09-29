import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/features/chat/widgets/composer_bar.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('ComposerBar renders and triggers onSend on enter', (WidgetTester tester) async {
    String? sentText;

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: ComposerBar(
            isGenerating: false,
            activePersonaName: 'Architect',
            onSend: (text) => sentText = text,
            onStop: () {},
            onPersonaTap: () {},
          ),
        ),
      ),
    );

    // Verify persona chip exists
    expect(find.text('Architect'), findsOneWidget);
    
    // Find text field
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // Enter text
    await tester.enterText(textField, 'Hello World');
    await tester.pumpAndSettle();

    // Verify Send button appears (hasText logic)
    expect(find.text(I18n.send), findsOneWidget);

    // Simulate Enter key
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(sentText, 'Hello World');
  });

  testWidgets('ComposerBar opens scrollable persona menu with primary and additional sections', (WidgetTester tester) async {
    String? selectedPersona;

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: ComposerBar(
            isGenerating: false,
            activePersonaName: 'Standard',
            onSend: (_) {},
            onStop: () {},
            onPersonaTap: () {},
            onSelectPersona: (p) => selectedPersona = p,
          ),
        ),
      ),
    );

    // Tap persona chip to open dropdown
    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();

    // Verify header and primary role are immediately in view
    expect(find.text(I18n.roleAndPrompt), findsOneWidget);
    expect(find.text(I18n.isGerman ? 'Senior-Entwickler' : 'Senior Coder'), findsOneWidget);

    // Scroll down to reveal the additional section
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(find.text(I18n.isGerman ? 'ZUSÄTZLICHE' : 'ADDITIONAL'), findsOneWidget);
    expect(find.text(I18n.isGerman ? 'Tiefenanalytiker' : 'Deep Analyst'), findsOneWidget);

    // Tap a role
    await tester.tap(find.text(I18n.isGerman ? 'Tiefenanalytiker' : 'Deep Analyst'));
    await tester.pumpAndSettle();

    expect(selectedPersona, I18n.isGerman ? 'Tiefenanalytiker' : 'Deep Analyst');
  });

  testWidgets('ComposerBar renders Model and Temperature chips and handles narrow layout without overflow', (WidgetTester tester) async {
    String? selectedModel;
    double? selectedTemp;

    await tester.binding.setSurfaceSize(const Size(400, 600));

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: ComposerBar(
            isGenerating: false,
            activePersonaName: 'Standard',
            selectedModel: 'llama3:latest',
            temperature: 0.7,
            onModelChanged: (m) => selectedModel = m,
            onTemperatureChanged: (t) => selectedTemp = t,
            onSend: (_) {},
            onStop: () {},
            onPersonaTap: () {},
          ),
        ),
      ),
    );

    // Verify chips render properly
    expect(find.text('llama3:latest'), findsOneWidget);
    expect(find.text('0.7'), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    // Open temperature popover
    await tester.tap(find.text('0.7'));
    await tester.pumpAndSettle();

    // Verify presets are displayed
    expect(find.text(I18n.tempCode), findsOneWidget);
    expect(find.text(I18n.tempNormal), findsOneWidget);
    expect(find.text(I18n.tempCreative), findsOneWidget);

    // Tap Code preset
    await tester.tap(find.text(I18n.tempCode));
    await tester.pumpAndSettle();
    expect(selectedTemp, 0.2);

    expect(selectedModel, isNull);

    // Reset surface size
    await tester.binding.setSurfaceSize(null);
  });
}
