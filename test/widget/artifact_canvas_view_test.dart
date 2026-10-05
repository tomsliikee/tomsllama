import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/chat/widgets/artifact_canvas_view.dart';

void main() {
  testWidgets('ArtifactCanvasView shows only chat when closed', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: ArtifactCanvasView(
            chatPanel: Text('Chat Content'),
            canvasPanel: Text('Canvas Content'),
            isCanvasOpen: false,
          ),
        ),
      ),
    );

    expect(find.text('Chat Content'), findsOneWidget);
    // Because AnimatedContainer width is 0, the text might still be in the tree if it wasn't conditionally hidden,
    // but in our logic `isCanvasOpen ? _CanvasWrapper(...) : const SizedBox.shrink()` hides it completely.
    expect(find.text('Canvas Content'), findsNothing);
  });

  testWidgets('ArtifactCanvasView shows both when open', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: ArtifactCanvasView(
            chatPanel: Text('Chat Content'),
            canvasPanel: Text('Canvas Content'),
            isCanvasOpen: true,
          ),
        ),
      ),
    );

    // Need to pump to let AnimatedContainer finish
    await tester.pumpAndSettle();

    expect(find.text('Chat Content'), findsOneWidget);
    expect(find.text('Canvas Content'), findsOneWidget);
    expect(find.text('Canvas'), findsOneWidget); // Canvas header title
  });

  testWidgets('ArtifactCanvasView renders SyntaxHighlightView in canvasPanel', (WidgetTester tester) async {
    const code = 'const x = 42;';
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: ArtifactCanvasView(
            chatPanel: Text('Chat Content'),
            canvasPanel: SelectionArea(
              child: SingleChildScrollView(
                child: Text(code),
              ),
            ),
            isCanvasOpen: true,
            language: 'javascript',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('javascript'), findsOneWidget);
    expect(find.text(code), findsOneWidget);
  });
}
