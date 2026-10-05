import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/chat/widgets/syntax_highlight_view.dart';

void main() {
  testWidgets('SyntaxHighlightView renders normalized language and code spans', (WidgetTester tester) async {
    const mdCode = '# Heading\n- Item 1';

    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: Scaffold(
          body: SelectionArea(
            child: SyntaxHighlightView(
              mdCode,
              language: 'md',
              theme: getHighlightCodeTheme(false, Colors.black),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SyntaxHighlightView), findsOneWidget);
    expect(find.textContaining('Heading'), findsOneWidget);
  });

  test('normalizeLanguage handles aliases properly', () {
    expect(SyntaxHighlightView.normalizeLanguage('md'), 'markdown');
    expect(SyntaxHighlightView.normalizeLanguage('MARKDOWN'), 'markdown');
    expect(SyntaxHighlightView.normalizeLanguage('mkd'), 'markdown');
    expect(SyntaxHighlightView.normalizeLanguage('python'), 'python');
    expect(SyntaxHighlightView.normalizeLanguage(''), isNull);
    expect(SyntaxHighlightView.normalizeLanguage(null), isNull);
  });
}
