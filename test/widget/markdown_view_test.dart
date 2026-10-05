import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/chat/widgets/markdown_view.dart';
import 'package:tomsllama/features/chat/widgets/code_block_view.dart';

void main() {
  testWidgets('MarkdownView renders text, code blocks, and latex', (WidgetTester tester) async {
    const mdText = '''
Here is some text.

```dart
print("Code block!");
```

And some math: \$\$E=mc^2\$\$
''';
    
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: MarkdownView(
            data: mdText,
          ),
        ),
      ),
    );

    // Give markdown a moment to parse
    await tester.pumpAndSettle();

    expect(find.textContaining('Here is some text.'), findsOneWidget);
    expect(find.byType(CodeBlockView), findsOneWidget);
  });

  testWidgets('MarkdownView renders md and markdown code blocks with code view', (WidgetTester tester) async {
    const mdText = '''
Here is a markdown block:

```markdown
# Documentation Title
- Item 1
- Item 2
```

And another with md alias:

```md
## Quick Notes
```
''';
    
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: MarkdownView(
              data: mdText,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CodeBlockView), findsNWidgets(2));
    expect(find.text('markdown'), findsOneWidget);
    expect(find.text('md'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsNWidgets(2));
  });
}
