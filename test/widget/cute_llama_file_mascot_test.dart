import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/workspace/widgets/cute_llama_file_mascot.dart';

void main() {
  testWidgets('CuteLlamaFileMascot renders custom painter and ticks animation', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: Center(
            child: CuteLlamaFileMascot(size: 80.0),
          ),
        ),
      ),
    );

    expect(find.byType(CuteLlamaFileMascot), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Advance 500ms
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);

    // Advance 3 seconds for file switch
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(CuteLlamaFileMascot), findsOneWidget);
  });
}
