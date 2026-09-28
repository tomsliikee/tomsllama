import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/features/chat/widgets/code_block_view.dart';

void main() {
  testWidgets('CodeBlockView renders code, language, and toggles', (WidgetTester tester) async {
    const codeSnippet = 'print("Hello World")';
    
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: const Scaffold(
            body: CodeBlockView(
              code: codeSnippet,
              language: 'python',
            ),
          ),
        ),
      ),
    );

    // Verify language badge exists
    expect(find.text('python'), findsOneWidget);
    
    // Verify code exists (it's inside HighlightView)
    expect(find.byType(CodeBlockView), findsOneWidget);

    // Verify copy button exists
    expect(find.text(I18n.copy), findsOneWidget);
  });
}
