import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/features/chat/widgets/file_drop_overlay.dart';

void main() {
  testWidgets('FileDropOverlay renders with animations, darkened backdrop and hints', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: FileDropOverlay(),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump(const Duration(milliseconds: 100));

    // Verify hint texts
    expect(find.text(I18n.dropFilesToAttach), findsOneWidget);
    expect(find.text(I18n.willAttachToConversation), findsOneWidget);

    // Verify CustomPaint with _CuteLlamaHoldingDocPainter
    expect(find.byType(CustomPaint), findsWidgets);

    // Animate forward through the wiggle loop
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text(I18n.dropFilesToAttach), findsOneWidget);
  });
}
