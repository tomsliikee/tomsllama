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
}
