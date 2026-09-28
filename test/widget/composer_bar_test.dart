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
    expect(find.text('ROLLE & HAUPTPROMPT'), findsOneWidget);
    expect(find.text('Senior Coder'), findsOneWidget);

    // Scroll down to reveal the additional section
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(find.text('ZUSÄTZLICHE'), findsOneWidget);
    expect(find.text('Deep Analyst'), findsOneWidget);

    // Tap a role
    await tester.tap(find.text('Deep Analyst'));
    await tester.pumpAndSettle();

    expect(selectedPersona, 'Deep Analyst');
  });
}
